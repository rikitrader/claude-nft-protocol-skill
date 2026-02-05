// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/BackedToken.sol";
import "../../contracts/SecureMintPolicy.sol";
import "../mocks/MockOracle.sol";

/**
 * @title MintFlowIntegrationTest
 * @notice End-to-end integration tests exercising the full mint flow through
 *         BackedToken, SecureMintPolicy, and MockOracle.
 */
contract MintFlowIntegrationTest is Test {
    // -------------------------------------------------------------------
    //  Events (re-declared locally for Solidity 0.8.20 emit compatibility)
    // -------------------------------------------------------------------

    event Minted(address indexed to, uint256 amount, uint256 newTotalSupply, uint256 oracleBacking, uint256 timestamp);
    event EpochReset(uint256 indexed epochNumber, uint256 timestamp);

    // -------------------------------------------------------------------
    //  State
    // -------------------------------------------------------------------

    BackedToken public token;
    SecureMintPolicy public policy;
    MockOracle public oracle;

    address public admin = makeAddr("admin");
    address public operator = makeAddr("operator");
    address public guardian = makeAddr("guardian");
    address public pauser = makeAddr("pauser");
    address public recipient = makeAddr("recipient");

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Policy configuration
    uint256 public constant GLOBAL_CAP = 1_000_000e18;     // 1M tokens
    uint256 public constant EPOCH_CAP = 100_000e18;         // 100K tokens per epoch
    uint256 public constant EPOCH_DURATION = 1 days;
    uint256 public constant MAX_STALENESS = 3600;            // 1 hour
    uint256 public constant MAX_DEVIATION = 500;             // 5% (basis points)
    uint256 public constant TIMELOCK_DELAY = 2 days;

    // -------------------------------------------------------------------
    //  Setup
    // -------------------------------------------------------------------

    function setUp() public {
        // Deploy contracts
        token = new BackedToken("USD Backed Token", "USDX", 18, admin);
        oracle = new MockOracle();
        policy = new SecureMintPolicy(
            address(token),
            address(oracle),
            GLOBAL_CAP,
            EPOCH_CAP,
            EPOCH_DURATION,
            MAX_STALENESS,
            MAX_DEVIATION,
            TIMELOCK_DELAY,
            admin
        );

        // Wire roles
        vm.startPrank(admin);
        // BackedToken: policy is the minter, pauser can pause token
        token.grantRole(MINTER_ROLE, address(policy));
        token.grantRole(PAUSER_ROLE, pauser);

        // SecureMintPolicy: operator can mint, guardian can pause policy
        policy.grantRole(OPERATOR_ROLE, operator);
        policy.grantRole(GUARDIAN_ROLE, guardian);
        vm.stopPrank();

        // Oracle: healthy, fresh, sufficient backing, no deviation
        oracle.setBackingAmount(GLOBAL_CAP);
        oracle.setHealthy(true);
        oracle.setLastUpdate(block.timestamp);
        oracle.setDeviation(0);
    }

    // -------------------------------------------------------------------
    //  Happy Path — Operator Mints via Policy
    // -------------------------------------------------------------------

    function test_MintFlow_HappyPath() public {
        uint256 mintAmount = 10_000e18;

        vm.prank(operator);
        policy.mint(recipient, mintAmount);

        assertEq(token.balanceOf(recipient), mintAmount);
        assertEq(token.totalSupply(), mintAmount);
    }

    function test_MintFlow_MultipleMints() public {
        vm.startPrank(operator);
        policy.mint(recipient, 10_000e18);
        policy.mint(recipient, 20_000e18);
        policy.mint(makeAddr("other"), 5_000e18);
        vm.stopPrank();

        assertEq(token.totalSupply(), 35_000e18);
        assertEq(token.balanceOf(recipient), 30_000e18);
    }

    function test_MintFlow_EmitsMintedEvent() public {
        uint256 mintAmount = 10_000e18;

        vm.prank(operator);
        vm.expectEmit(true, false, false, true);
        emit Minted(
            recipient,
            mintAmount,
            mintAmount,
            GLOBAL_CAP,
            block.timestamp
        );
        policy.mint(recipient, mintAmount);
    }

    // -------------------------------------------------------------------
    //  Oracle Unhealthy — Mint Fails
    // -------------------------------------------------------------------

    function test_MintFlow_RevertsWhenOracleUnhealthy() public {
        oracle.setHealthy(false);

        vm.prank(operator);
        vm.expectRevert(SecureMintPolicy.OracleUnhealthy.selector);
        policy.mint(recipient, 1_000e18);
    }

    // -------------------------------------------------------------------
    //  Oracle Stale — Mint Fails
    // -------------------------------------------------------------------

    function test_MintFlow_RevertsWhenOracleStale() public {
        // Make oracle data stale by setting lastUpdate far in the past
        uint256 staleTimestamp = block.timestamp - MAX_STALENESS - 1;
        oracle.setLastUpdate(staleTimestamp);

        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(
                SecureMintPolicy.OracleStale.selector,
                staleTimestamp,
                MAX_STALENESS
            )
        );
        policy.mint(recipient, 1_000e18);
    }

    function test_MintFlow_SucceedsAtExactStalenessThreshold() public {
        // lastUpdate = block.timestamp - maxStaleness => age == maxStaleness
        // Condition: block.timestamp - lastUpdate > maxStaleness => false => passes
        oracle.setLastUpdate(block.timestamp - MAX_STALENESS);

        vm.prank(operator);
        policy.mint(recipient, 1_000e18);
        assertEq(token.totalSupply(), 1_000e18);
    }

    // -------------------------------------------------------------------
    //  Oracle Deviation Exceeded — Mint Fails
    // -------------------------------------------------------------------

    function test_MintFlow_RevertsWhenDeviationExceeded() public {
        oracle.setDeviation(MAX_DEVIATION + 1);

        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(
                SecureMintPolicy.OracleDeviationExceeded.selector,
                MAX_DEVIATION + 1,
                MAX_DEVIATION
            )
        );
        policy.mint(recipient, 1_000e18);
    }

    // -------------------------------------------------------------------
    //  Backing Insufficient — Mint Fails
    // -------------------------------------------------------------------

    function test_MintFlow_RevertsWhenBackingInsufficient() public {
        // Set backing to 500 tokens, try to mint 1000
        oracle.setBackingAmount(500e18);

        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(
                SecureMintPolicy.BackingInsufficient.selector,
                500e18,
                1_000e18
            )
        );
        policy.mint(recipient, 1_000e18);
    }

    function test_MintFlow_RevertsWhenPostMintExceedsBacking() public {
        // Mint some tokens first, then try to mint more than backing allows
        oracle.setBackingAmount(50_000e18);

        vm.startPrank(operator);
        policy.mint(recipient, 40_000e18); // success, postMint = 40k, backing = 50k

        vm.expectRevert(
            abi.encodeWithSelector(
                SecureMintPolicy.BackingInsufficient.selector,
                50_000e18,
                55_000e18
            )
        );
        policy.mint(recipient, 15_000e18); // postMint = 55k > backing = 50k
        vm.stopPrank();
    }

    // -------------------------------------------------------------------
    //  Epoch Cap Exceeded — Mint Fails
    // -------------------------------------------------------------------

    function test_MintFlow_RevertsWhenEpochCapExceeded() public {
        vm.startPrank(operator);
        // Mint up to the epoch cap
        policy.mint(recipient, EPOCH_CAP);

        // Next mint should fail
        vm.expectRevert(
            abi.encodeWithSelector(
                SecureMintPolicy.EpochCapExceeded.selector,
                1e18,
                0
            )
        );
        policy.mint(recipient, 1e18);
        vm.stopPrank();
    }

    function test_MintFlow_RevertsWhenSingleMintExceedsEpochCap() public {
        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(
                SecureMintPolicy.EpochCapExceeded.selector,
                EPOCH_CAP + 1e18,
                EPOCH_CAP
            )
        );
        policy.mint(recipient, EPOCH_CAP + 1e18);
    }

    // -------------------------------------------------------------------
    //  Global Supply Cap Exceeded — Mint Fails
    // -------------------------------------------------------------------

    function test_MintFlow_RevertsWhenGlobalCapExceeded() public {
        // Deploy a separate policy with unlimited epoch cap so only the
        // global supply cap is the binding constraint.
        BackedToken token3 = new BackedToken("Test", "TST", 18, admin);
        MockOracle oracle3 = new MockOracle();
        oracle3.setBackingAmount(GLOBAL_CAP + 1e18);
        oracle3.setHealthy(true);
        oracle3.setLastUpdate(block.timestamp);
        oracle3.setDeviation(0);

        SecureMintPolicy policy3 = new SecureMintPolicy(
            address(token3),
            address(oracle3),
            GLOBAL_CAP,              // global cap = 1M
            type(uint256).max,       // epoch cap = unlimited
            EPOCH_DURATION,
            MAX_STALENESS,
            MAX_DEVIATION,
            TIMELOCK_DELAY,
            admin
        );

        vm.startPrank(admin);
        token3.grantRole(MINTER_ROLE, address(policy3));
        policy3.grantRole(OPERATOR_ROLE, operator);
        vm.stopPrank();

        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(
                SecureMintPolicy.GlobalSupplyCapExceeded.selector,
                GLOBAL_CAP + 1e18,
                GLOBAL_CAP
            )
        );
        policy3.mint(recipient, GLOBAL_CAP + 1e18);
    }

    function test_MintFlow_GlobalCapCheck_AfterPartialMint() public {
        // Use separate setup with low global cap
        BackedToken token2 = new BackedToken("Test", "TST", 18, admin);
        MockOracle oracle2 = new MockOracle();
        oracle2.setBackingAmount(200_000e18);
        oracle2.setHealthy(true);
        oracle2.setLastUpdate(block.timestamp);
        oracle2.setDeviation(0);

        SecureMintPolicy policy2 = new SecureMintPolicy(
            address(token2),
            address(oracle2),
            50_000e18,   // global cap = 50k
            100_000e18,  // epoch cap = 100k (larger than global cap)
            EPOCH_DURATION,
            MAX_STALENESS,
            MAX_DEVIATION,
            TIMELOCK_DELAY,
            admin
        );

        vm.startPrank(admin);
        token2.grantRole(MINTER_ROLE, address(policy2));
        policy2.grantRole(OPERATOR_ROLE, operator);
        vm.stopPrank();

        vm.startPrank(operator);
        policy2.mint(recipient, 40_000e18); // OK, under global cap

        vm.expectRevert(
            abi.encodeWithSelector(
                SecureMintPolicy.GlobalSupplyCapExceeded.selector,
                55_000e18,
                50_000e18
            )
        );
        policy2.mint(recipient, 15_000e18); // 40k + 15k = 55k > 50k global cap
        vm.stopPrank();
    }

    // -------------------------------------------------------------------
    //  Epoch Rollover — Mint Succeeds Again
    // -------------------------------------------------------------------

    function test_MintFlow_EpochRollover_ResetsCapacity() public {
        vm.startPrank(operator);
        // Exhaust epoch cap
        policy.mint(recipient, EPOCH_CAP);

        // Cannot mint more in same epoch
        vm.expectRevert();
        policy.mint(recipient, 1e18);

        vm.stopPrank();

        // Advance time by one epoch
        vm.warp(block.timestamp + EPOCH_DURATION);

        // Fresh oracle timestamp for the new epoch
        oracle.setLastUpdate(block.timestamp);

        vm.prank(operator);
        policy.mint(recipient, 50_000e18);

        assertEq(token.totalSupply(), EPOCH_CAP + 50_000e18);
    }

    function test_MintFlow_EpochRollover_EmitsEpochReset() public {
        // Advance past first epoch
        vm.warp(block.timestamp + EPOCH_DURATION);
        oracle.setLastUpdate(block.timestamp);

        vm.prank(operator);
        vm.expectEmit(true, false, false, true);
        emit EpochReset(2, block.timestamp);
        policy.mint(recipient, 1_000e18);
    }

    function test_MintFlow_MultipleEpochRollover() public {
        // Exhaust first epoch
        vm.prank(operator);
        policy.mint(recipient, EPOCH_CAP);

        // Advance past 3 full epochs
        vm.warp(block.timestamp + EPOCH_DURATION * 3);
        oracle.setLastUpdate(block.timestamp);

        // Should be able to mint again (fresh epoch)
        vm.prank(operator);
        policy.mint(recipient, EPOCH_CAP);

        assertEq(token.totalSupply(), EPOCH_CAP * 2);
    }

    // -------------------------------------------------------------------
    //  Pause / Unpause — Blocks Mint, Re-enables
    // -------------------------------------------------------------------

    function test_MintFlow_PauseBlocksMint() public {
        // Guardian pauses the policy
        vm.prank(guardian);
        policy.pause();

        vm.prank(operator);
        vm.expectRevert();  // Pausable: EnforcedPause
        policy.mint(recipient, 1_000e18);
    }

    function test_MintFlow_UnpauseReenablesMint() public {
        // Pause
        vm.prank(guardian);
        policy.pause();

        // Unpause (admin only)
        vm.prank(admin);
        policy.unpause();

        // Mint should work again
        vm.prank(operator);
        policy.mint(recipient, 1_000e18);
        assertEq(token.totalSupply(), 1_000e18);
    }

    function test_MintFlow_TokenPauseAlsoBlocksMint() public {
        // Pause the token itself (not the policy)
        vm.prank(pauser);
        token.pause();

        // Policy is not paused, but token is paused => mint reverts at token._update
        vm.prank(operator);
        vm.expectRevert();
        policy.mint(recipient, 1_000e18);
    }

    function test_MintFlow_TokenUnpauseAfterPause() public {
        vm.prank(pauser);
        token.pause();

        vm.prank(pauser);
        token.unpause();

        vm.prank(operator);
        policy.mint(recipient, 1_000e18);
        assertEq(token.totalSupply(), 1_000e18);
    }

    // -------------------------------------------------------------------
    //  Access Control — Only Operator Can Mint via Policy
    // -------------------------------------------------------------------

    function test_MintFlow_RevertsNonOperator() public {
        vm.prank(admin);
        vm.expectRevert();
        policy.mint(recipient, 1_000e18);
    }

    function test_MintFlow_RevertsZeroAddress() public {
        vm.prank(operator);
        vm.expectRevert(SecureMintPolicy.ZeroAddress.selector);
        policy.mint(address(0), 1_000e18);
    }

    function test_MintFlow_RevertsZeroAmount() public {
        vm.prank(operator);
        vm.expectRevert(SecureMintPolicy.ZeroAmount.selector);
        policy.mint(recipient, 0);
    }

    // -------------------------------------------------------------------
    //  Direct Token Mint Gated — Only Policy Can Mint Token
    // -------------------------------------------------------------------

    function test_MintFlow_DirectTokenMintRevertsForNonMinter() public {
        vm.prank(operator);
        vm.expectRevert();
        token.mint(recipient, 1_000e18);
    }

    // -------------------------------------------------------------------
    //  Full Lifecycle — Multiple Epochs with Changing Conditions
    // -------------------------------------------------------------------

    function test_MintFlow_FullLifecycle() public {
        // Epoch 1: mint 50k successfully
        vm.prank(operator);
        policy.mint(recipient, 50_000e18);
        assertEq(token.totalSupply(), 50_000e18);

        // Oracle becomes unhealthy mid-epoch
        oracle.setHealthy(false);
        vm.prank(operator);
        vm.expectRevert(SecureMintPolicy.OracleUnhealthy.selector);
        policy.mint(recipient, 1_000e18);

        // Oracle recovers
        oracle.setHealthy(true);
        vm.prank(operator);
        policy.mint(recipient, 10_000e18);
        assertEq(token.totalSupply(), 60_000e18);

        // Guardian pauses
        vm.prank(guardian);
        policy.pause();

        vm.prank(operator);
        vm.expectRevert();
        policy.mint(recipient, 1_000e18);

        // Admin unpauses
        vm.prank(admin);
        policy.unpause();

        // Advance to epoch 2
        vm.warp(block.timestamp + EPOCH_DURATION);
        oracle.setLastUpdate(block.timestamp);

        // Mint in epoch 2
        vm.prank(operator);
        policy.mint(recipient, EPOCH_CAP);
        assertEq(token.totalSupply(), 60_000e18 + EPOCH_CAP);

        // Epoch 2 is exhausted
        vm.prank(operator);
        vm.expectRevert();
        policy.mint(recipient, 1e18);

        // Advance to epoch 3 and verify mint succeeds
        vm.warp(block.timestamp + EPOCH_DURATION);
        oracle.setLastUpdate(block.timestamp);

        vm.prank(operator);
        policy.mint(recipient, 1_000e18);
        assertEq(token.totalSupply(), 60_000e18 + EPOCH_CAP + 1_000e18);
    }
}
