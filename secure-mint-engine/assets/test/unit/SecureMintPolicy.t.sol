// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/BackedToken.sol";
import "../../contracts/SecureMintPolicy.sol";
import "../mocks/MockOracle.sol";

/**
 * @title SecureMintPolicyTest
 * @notice Unit tests for the SecureMintPolicy oracle-gated mint policy.
 *         This is the most critical test file as SecureMintPolicy enforces
 *         all 6 mint conditions that protect the protocol.
 */
contract SecureMintPolicyTest is Test {
    // -------------------------------------------------------------------
    //  Events (re-declared locally for Solidity 0.8.20 emit compatibility)
    // -------------------------------------------------------------------

    event Minted(address indexed to, uint256 amount, uint256 newTotalSupply, uint256 oracleBacking, uint256 timestamp);

    // -------------------------------------------------------------------
    //  State
    // -------------------------------------------------------------------

    BackedToken public token;
    MockOracle public oracle;
    SecureMintPolicy public policy;

    address public admin = makeAddr("admin");
    address public operator = makeAddr("operator");
    address public guardian = makeAddr("guardian");
    address public user = makeAddr("user");

    // Policy configuration constants
    uint256 public constant GLOBAL_CAP = 10_000_000e18; // 10M tokens
    uint256 public constant EPOCH_CAP = 1_000_000e18;   // 1M per epoch
    uint256 public constant EPOCH_DURATION = 24 hours;
    uint256 public constant MAX_STALENESS = 3600;        // 1 hour
    uint256 public constant MAX_DEVIATION = 500;         // 5% in bps
    uint256 public constant TIMELOCK_DELAY = 2 days;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    // -------------------------------------------------------------------
    //  Setup
    // -------------------------------------------------------------------

    function setUp() public {
        // Deploy token
        token = new BackedToken("USD Backed Token", "USDX", 18, admin);

        // Deploy mock oracle with ample backing
        oracle = new MockOracle();
        oracle.setBackingAmount(100_000_000e18); // 100M backing
        oracle.setLastUpdate(block.timestamp);

        // Deploy policy
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

        // Grant MINTER_ROLE on the token to the policy contract
        vm.startPrank(admin);
        token.grantRole(MINTER_ROLE, address(policy));
        policy.grantRole(OPERATOR_ROLE, operator);
        policy.grantRole(GUARDIAN_ROLE, guardian);
        vm.stopPrank();
    }

    // -------------------------------------------------------------------
    //  Happy Path: All Conditions Pass
    // -------------------------------------------------------------------

    function test_MintWhenAllConditionsPass() public {
        uint256 mintAmount = 1000e18;

        vm.prank(operator);
        policy.mint(user, mintAmount);

        assertEq(token.balanceOf(user), mintAmount);
        assertEq(token.totalSupply(), mintAmount);
        assertEq(policy.epochMinted(), mintAmount);
    }

    function test_MintEmitsEvent() public {
        uint256 mintAmount = 500e18;

        vm.prank(operator);
        vm.expectEmit(true, false, false, true);
        emit Minted(user, mintAmount, mintAmount, 100_000_000e18, block.timestamp);
        policy.mint(user, mintAmount);
    }

    function test_MintMultipleTimesWithinEpoch() public {
        vm.startPrank(operator);
        policy.mint(user, 100_000e18);
        policy.mint(user, 200_000e18);
        policy.mint(user, 300_000e18);
        vm.stopPrank();

        assertEq(token.totalSupply(), 600_000e18);
        assertEq(policy.epochMinted(), 600_000e18);
    }

    // -------------------------------------------------------------------
    //  Condition 1: Backing Insufficient
    // -------------------------------------------------------------------

    function test_RevertWhenBackingInsufficient() public {
        // Set oracle backing below the post-mint supply
        oracle.setBackingAmount(500e18);

        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(
                SecureMintPolicy.BackingInsufficient.selector,
                500e18,
                1000e18
            )
        );
        policy.mint(user, 1000e18);
    }

    function test_RevertWhenBackingExactlyEqualToCurrent_ButNotPostMint() public {
        // Mint some tokens first
        vm.prank(operator);
        policy.mint(user, 500e18);

        // Set backing to exactly current supply (not enough for more)
        oracle.setBackingAmount(500e18);

        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(
                SecureMintPolicy.BackingInsufficient.selector,
                500e18,
                501e18
            )
        );
        policy.mint(user, 1e18);
    }

    function test_MintWhenBackingExactlyEqualsPostMintSupply() public {
        oracle.setBackingAmount(1000e18);

        vm.prank(operator);
        policy.mint(user, 1000e18);

        assertEq(token.totalSupply(), 1000e18);
    }

    // -------------------------------------------------------------------
    //  Condition 2: Oracle Unhealthy
    // -------------------------------------------------------------------

    function test_RevertWhenOracleUnhealthy() public {
        oracle.setHealthy(false);

        vm.prank(operator);
        vm.expectRevert(SecureMintPolicy.OracleUnhealthy.selector);
        policy.mint(user, 1000e18);
    }

    // -------------------------------------------------------------------
    //  Condition 3: Oracle Stale
    // -------------------------------------------------------------------

    function test_RevertWhenOracleStale() public {
        // Set last update to more than maxStaleness ago
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
        policy.mint(user, 1000e18);
    }

    function test_MintWhenOracleAtExactStalenessThreshold() public {
        // Set last update to exactly maxStaleness ago (should still pass)
        oracle.setLastUpdate(block.timestamp - MAX_STALENESS);

        vm.prank(operator);
        policy.mint(user, 1000e18);
        assertEq(token.totalSupply(), 1000e18);
    }

    // -------------------------------------------------------------------
    //  Condition 4: Deviation Exceeded
    // -------------------------------------------------------------------

    function test_RevertWhenDeviationExceeded() public {
        // Set deviation above the max (500 bps = 5%)
        oracle.setDeviation(501);

        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(
                SecureMintPolicy.OracleDeviationExceeded.selector,
                501,
                MAX_DEVIATION
            )
        );
        policy.mint(user, 1000e18);
    }

    function test_MintWhenDeviationAtExactThreshold() public {
        oracle.setDeviation(MAX_DEVIATION);

        vm.prank(operator);
        policy.mint(user, 1000e18);
        assertEq(token.totalSupply(), 1000e18);
    }

    // -------------------------------------------------------------------
    //  Condition 5: Epoch Cap Exceeded
    // -------------------------------------------------------------------

    function test_RevertWhenEpochCapExceeded() public {
        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(
                SecureMintPolicy.EpochCapExceeded.selector,
                EPOCH_CAP + 1,
                EPOCH_CAP
            )
        );
        policy.mint(user, EPOCH_CAP + 1);
    }

    function test_RevertWhenCumulativeEpochCapExceeded() public {
        // Mint up to the cap
        vm.prank(operator);
        policy.mint(user, EPOCH_CAP);

        // Try to mint 1 more token
        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(
                SecureMintPolicy.EpochCapExceeded.selector,
                1,
                0
            )
        );
        policy.mint(user, 1);
    }

    function test_MintExactEpochCap() public {
        vm.prank(operator);
        policy.mint(user, EPOCH_CAP);

        assertEq(token.totalSupply(), EPOCH_CAP);
        assertEq(policy.epochMinted(), EPOCH_CAP);
        assertEq(policy.epochRemaining(), 0);
    }

    // -------------------------------------------------------------------
    //  Condition 6: Global Cap Exceeded
    // -------------------------------------------------------------------

    function test_RevertWhenGlobalCapExceeded() public {
        // Set epoch cap very high so it does not interfere
        // We will work within the original caps by minting across epochs
        // Instead, set backing high and mint exactly to global cap over epochs
        // Simpler: just try to mint more than global cap in one go with high epoch cap

        // Re-deploy with a high epoch cap to isolate global cap testing
        SecureMintPolicy policyBigEpoch = new SecureMintPolicy(
            address(token),
            address(oracle),
            GLOBAL_CAP,        // 10M global cap
            GLOBAL_CAP + 1e18, // epoch cap bigger than global cap
            EPOCH_DURATION,
            MAX_STALENESS,
            MAX_DEVIATION,
            TIMELOCK_DELAY,
            admin
        );

        vm.startPrank(admin);
        token.grantRole(MINTER_ROLE, address(policyBigEpoch));
        policyBigEpoch.grantRole(OPERATOR_ROLE, operator);
        vm.stopPrank();

        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(
                SecureMintPolicy.GlobalSupplyCapExceeded.selector,
                GLOBAL_CAP + 1,
                GLOBAL_CAP
            )
        );
        policyBigEpoch.mint(user, GLOBAL_CAP + 1);
    }

    function test_MintExactGlobalCap() public {
        // Deploy a policy where epoch cap equals global cap
        SecureMintPolicy policyBigEpoch = new SecureMintPolicy(
            address(token),
            address(oracle),
            GLOBAL_CAP,
            GLOBAL_CAP,
            EPOCH_DURATION,
            MAX_STALENESS,
            MAX_DEVIATION,
            TIMELOCK_DELAY,
            admin
        );

        vm.startPrank(admin);
        token.grantRole(MINTER_ROLE, address(policyBigEpoch));
        policyBigEpoch.grantRole(OPERATOR_ROLE, operator);
        vm.stopPrank();

        vm.prank(operator);
        policyBigEpoch.mint(user, GLOBAL_CAP);
        assertEq(token.totalSupply(), GLOBAL_CAP);
    }

    // -------------------------------------------------------------------
    //  Condition 7: Paused
    // -------------------------------------------------------------------

    function test_RevertWhenPaused() public {
        vm.prank(guardian);
        policy.pause();

        vm.prank(operator);
        vm.expectRevert();
        policy.mint(user, 1000e18);
    }

    function test_MintAfterUnpause() public {
        vm.prank(guardian);
        policy.pause();

        vm.prank(admin);
        policy.unpause();

        vm.prank(operator);
        policy.mint(user, 1000e18);
        assertEq(token.totalSupply(), 1000e18);
    }

    // -------------------------------------------------------------------
    //  Condition 8: Caller Role
    // -------------------------------------------------------------------

    function test_RevertWhenCallerLacksOperatorRole() public {
        vm.prank(user);
        vm.expectRevert();
        policy.mint(user, 1000e18);
    }

    function test_RevertWhenMintingZeroAmount() public {
        vm.prank(operator);
        vm.expectRevert(SecureMintPolicy.ZeroAmount.selector);
        policy.mint(user, 0);
    }

    function test_RevertWhenMintingToZeroAddress() public {
        vm.prank(operator);
        vm.expectRevert(SecureMintPolicy.ZeroAddress.selector);
        policy.mint(address(0), 1000e18);
    }

    // -------------------------------------------------------------------
    //  Epoch Advancement
    // -------------------------------------------------------------------

    function test_EpochAdvancement() public {
        // Use full epoch cap
        vm.prank(operator);
        policy.mint(user, EPOCH_CAP);
        assertEq(policy.epochRemaining(), 0);
        assertEq(policy.epochNumber(), 1);

        // Warp to the next epoch
        vm.warp(block.timestamp + EPOCH_DURATION);

        // Epoch should reset, allowing minting again
        vm.prank(operator);
        policy.mint(user, 500_000e18);

        assertEq(policy.epochNumber(), 2);
        assertEq(policy.epochMinted(), 500_000e18);
        assertEq(policy.epochRemaining(), EPOCH_CAP - 500_000e18);
    }

    function test_EpochAdvancesMultipleEpochs() public {
        vm.prank(operator);
        policy.mint(user, 100e18);
        assertEq(policy.epochNumber(), 1);

        // Warp 3 epochs ahead
        vm.warp(block.timestamp + EPOCH_DURATION * 3);

        vm.prank(operator);
        policy.mint(user, 200e18);

        // Should be at epoch 4 (advanced 3 times)
        assertEq(policy.epochNumber(), 4);
        assertEq(policy.epochMinted(), 200e18);
    }

    function test_EpochBoundaryNoDoubleAllocation() public {
        // Mint right up to the epoch cap
        vm.prank(operator);
        policy.mint(user, EPOCH_CAP);

        // Warp to exactly the epoch boundary
        vm.warp(block.timestamp + EPOCH_DURATION);

        // First mint in new epoch should succeed
        vm.prank(operator);
        policy.mint(user, EPOCH_CAP);

        // Second mint in same block should fail (epoch already used up)
        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(
                SecureMintPolicy.EpochCapExceeded.selector,
                1,
                0
            )
        );
        policy.mint(user, 1);
    }

    function test_EpochRemainingView() public {
        assertEq(policy.epochRemaining(), EPOCH_CAP);

        vm.prank(operator);
        policy.mint(user, 300_000e18);

        assertEq(policy.epochRemaining(), EPOCH_CAP - 300_000e18);
    }

    // -------------------------------------------------------------------
    //  Timelock: Propose + Execute
    // -------------------------------------------------------------------

    function test_TimelockProposalExecution() public {
        uint256 newGlobalCap = 20_000_000e18; // Double the cap

        // Propose
        vm.prank(admin);
        policy.proposeGlobalCapChange(newGlobalCap);

        // Compute the changeId (matches the contract's keccak256 encoding)
        bytes32 changeId = keccak256(abi.encode("globalSupplyCap", newGlobalCap, block.timestamp));

        // Wait for timelock to elapse
        vm.warp(block.timestamp + TIMELOCK_DELAY);

        // Execute
        vm.prank(admin);
        policy.executeGlobalCapChange(changeId);

        assertEq(policy.globalSupplyCap(), newGlobalCap);
    }

    function test_RevertTimelockNotElapsed() public {
        uint256 newGlobalCap = 20_000_000e18;

        vm.prank(admin);
        policy.proposeGlobalCapChange(newGlobalCap);

        bytes32 changeId = keccak256(abi.encode("globalSupplyCap", newGlobalCap, block.timestamp));

        // Try to execute before timelock elapses (warp only half the delay)
        vm.warp(block.timestamp + TIMELOCK_DELAY - 1);

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                SecureMintPolicy.TimelockNotElapsed.selector,
                block.timestamp + 1 // availableAt is 1 second in the future
            )
        );
        policy.executeGlobalCapChange(changeId);
    }

    function test_TimelockEpochCapChange() public {
        uint256 newEpochCap = 2_000_000e18;
        uint256 proposeTime = block.timestamp;

        vm.prank(admin);
        policy.proposeEpochCapChange(newEpochCap);

        bytes32 changeId = keccak256(abi.encode("epochMintCap", newEpochCap, proposeTime));

        vm.warp(proposeTime + TIMELOCK_DELAY);

        vm.prank(admin);
        policy.executeEpochCapChange(changeId);

        assertEq(policy.epochMintCap(), newEpochCap);
    }

    function test_TimelockCancelChange() public {
        uint256 newGlobalCap = 20_000_000e18;
        uint256 proposeTime = block.timestamp;

        vm.prank(admin);
        policy.proposeGlobalCapChange(newGlobalCap);

        bytes32 changeId = keccak256(abi.encode("globalSupplyCap", newGlobalCap, proposeTime));

        vm.prank(admin);
        policy.cancelChange(changeId);

        // Executing after cancel should revert
        vm.warp(proposeTime + TIMELOCK_DELAY);
        vm.prank(admin);
        vm.expectRevert(SecureMintPolicy.NoPendingChange.selector);
        policy.executeGlobalCapChange(changeId);
    }

    function test_RevertExecuteNonexistentChange() public {
        bytes32 fakeChangeId = keccak256("nonexistent");

        vm.prank(admin);
        vm.expectRevert(SecureMintPolicy.NoPendingChange.selector);
        policy.executeGlobalCapChange(fakeChangeId);
    }

    // -------------------------------------------------------------------
    //  EmergencyPause Integration Hook
    // -------------------------------------------------------------------

    function test_OnPauseLevelChanged_PausesAtLevel1() public {
        // Register a mock emergencyPause address
        address mockEmergencyPause = makeAddr("emergencyPause");
        vm.prank(admin);
        policy.setEmergencyPause(mockEmergencyPause);

        // Level 1 should pause the policy
        vm.prank(mockEmergencyPause);
        policy.onPauseLevelChanged(1);
        assertTrue(policy.paused());
    }

    function test_OnPauseLevelChanged_UnpausesAtLevel0() public {
        address mockEmergencyPause = makeAddr("emergencyPause");
        vm.prank(admin);
        policy.setEmergencyPause(mockEmergencyPause);

        // Pause first
        vm.prank(mockEmergencyPause);
        policy.onPauseLevelChanged(2);
        assertTrue(policy.paused());

        // Level 0 should unpause
        vm.prank(mockEmergencyPause);
        policy.onPauseLevelChanged(0);
        assertFalse(policy.paused());
    }

    function test_OnPauseLevelChanged_RevertsFromNonEmergencyPause() public {
        address mockEmergencyPause = makeAddr("emergencyPause");
        vm.prank(admin);
        policy.setEmergencyPause(mockEmergencyPause);

        vm.prank(user);
        vm.expectRevert("SecureMintPolicy: caller is not EmergencyPause");
        policy.onPauseLevelChanged(1);
    }

    // -------------------------------------------------------------------
    //  View Functions
    // -------------------------------------------------------------------

    function test_GlobalRemainingUnlimited() public {
        // Deploy policy with globalCap = 0 (unlimited)
        SecureMintPolicy unlimitedPolicy = new SecureMintPolicy(
            address(token),
            address(oracle),
            0, // unlimited
            EPOCH_CAP,
            EPOCH_DURATION,
            MAX_STALENESS,
            MAX_DEVIATION,
            TIMELOCK_DELAY,
            admin
        );

        assertEq(unlimitedPolicy.globalRemaining(), type(uint256).max);
    }

    function test_GlobalRemainingWithCap() public view {
        assertEq(policy.globalRemaining(), GLOBAL_CAP);
    }

    // -------------------------------------------------------------------
    //  Constructor Validation
    // -------------------------------------------------------------------

    function test_ConstructorRevertsZeroToken() public {
        vm.expectRevert(SecureMintPolicy.ZeroAddress.selector);
        new SecureMintPolicy(
            address(0), address(oracle), GLOBAL_CAP, EPOCH_CAP,
            EPOCH_DURATION, MAX_STALENESS, MAX_DEVIATION, TIMELOCK_DELAY, admin
        );
    }

    function test_ConstructorRevertsZeroOracle() public {
        vm.expectRevert(SecureMintPolicy.ZeroAddress.selector);
        new SecureMintPolicy(
            address(token), address(0), GLOBAL_CAP, EPOCH_CAP,
            EPOCH_DURATION, MAX_STALENESS, MAX_DEVIATION, TIMELOCK_DELAY, admin
        );
    }

    function test_ConstructorRevertsZeroAdmin() public {
        vm.expectRevert(SecureMintPolicy.ZeroAddress.selector);
        new SecureMintPolicy(
            address(token), address(oracle), GLOBAL_CAP, EPOCH_CAP,
            EPOCH_DURATION, MAX_STALENESS, MAX_DEVIATION, TIMELOCK_DELAY, address(0)
        );
    }
}
