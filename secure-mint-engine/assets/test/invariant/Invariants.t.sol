// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "../../contracts/BackedToken.sol";
import "../../contracts/SecureMintPolicy.sol";
import "../../contracts/TreasuryVault.sol";
import "../../contracts/EmergencyPause.sol";
import "../mocks/MockOracle.sol";
import "../mocks/MockERC20.sol";

// =====================================================================
//  Handler: Provides bounded random actions for the invariant fuzzer
// =====================================================================

/**
 * @title InvariantHandler
 * @notice Randomly calls mint, burn, pause, deposit, and withdraw
 *         through the protocol contracts to explore state space.
 */
contract InvariantHandler is Test {
    BackedToken public token;
    SecureMintPolicy public policy;
    TreasuryVault public vault;
    EmergencyPause public ep;
    MockOracle public oracle;
    MockERC20 public collateral;

    address public admin;
    address public operator;
    address public guardian;
    address public treasurer;
    address public user;

    // Track ghost variables for invariant assertions
    uint256 public totalMinted;
    uint256 public totalBurned;
    uint256 public mintCallCount;
    uint256 public mintRevertCount;

    constructor(
        BackedToken token_,
        SecureMintPolicy policy_,
        TreasuryVault vault_,
        EmergencyPause ep_,
        MockOracle oracle_,
        MockERC20 collateral_,
        address admin_,
        address operator_,
        address guardian_,
        address treasurer_,
        address user_
    ) {
        token = token_;
        policy = policy_;
        vault = vault_;
        ep = ep_;
        oracle = oracle_;
        collateral = collateral_;
        admin = admin_;
        operator = operator_;
        guardian = guardian_;
        treasurer = treasurer_;
        user = user_;
    }

    // -------------------------------------------------------------------
    //  Actions
    // -------------------------------------------------------------------

    /**
     * @notice Attempt to mint a bounded amount of tokens through the policy.
     */
    function mint(uint256 amount) external {
        amount = bound(amount, 1, 100_000e18);

        // Keep oracle fresh for minting
        oracle.setLastUpdate(block.timestamp);

        vm.prank(operator);
        try policy.mint(user, amount) {
            totalMinted += amount;
            mintCallCount++;
        } catch {
            mintRevertCount++;
        }
    }

    /**
     * @notice Burn tokens that the user holds.
     */
    function burn(uint256 amount) external {
        uint256 balance = token.balanceOf(user);
        if (balance == 0) return;

        amount = bound(amount, 1, balance);

        vm.prank(user);
        try token.burn(amount) {
            totalBurned += amount;
        } catch {}
    }

    /**
     * @notice Toggle pause on the EmergencyPause contract.
     */
    function togglePause(uint256 seed) external {
        uint8 currentLevel = uint8(ep.currentLevel());

        if (seed % 2 == 0 && currentLevel < 3) {
            // Escalate by one level
            uint8 nextLevel = currentLevel + 1;
            vm.prank(guardian);
            try ep.escalate(EmergencyPause.PauseLevel(nextLevel), "handler-escalate") {}
            catch {}
        } else if (currentLevel > 0) {
            // Try to deescalate by one level
            uint8 prevLevel = currentLevel - 1;
            vm.prank(admin);
            try ep.deescalate(EmergencyPause.PauseLevel(prevLevel), "handler-deescalate") {}
            catch {}
        }
    }

    /**
     * @notice Deposit collateral into a random tier.
     */
    function deposit(uint256 amount, uint256 tierSeed) external {
        amount = bound(amount, 1e6, 1_000_000e6);
        TreasuryVault.Tier tier = TreasuryVault.Tier(tierSeed % 4);

        vm.prank(treasurer);
        try vault.deposit(tier, amount) {}
        catch {}
    }

    /**
     * @notice Withdraw collateral from a random tier.
     */
    function withdraw(uint256 amount, uint256 tierSeed) external {
        TreasuryVault.Tier tier = TreasuryVault.Tier(tierSeed % 4);
        uint256 tierBal = vault.tierBalance(tier);
        if (tierBal == 0) return;

        amount = bound(amount, 1, tierBal);

        vm.prank(treasurer);
        try vault.withdraw(tier, amount, treasurer) {}
        catch {}
    }

    /**
     * @notice Advance time by a bounded amount to trigger epoch rollovers.
     */
    function warpTime(uint256 seconds_) external {
        seconds_ = bound(seconds_, 1, 48 hours);
        vm.warp(block.timestamp + seconds_);
        // Keep oracle fresh after time warp
        oracle.setLastUpdate(block.timestamp);
    }
}

// =====================================================================
//  Invariant Test Suite
// =====================================================================

/**
 * @title InvariantTests
 * @notice Foundry invariant tests that verify protocol-wide safety properties
 *         hold under random sequences of actions.
 */
contract InvariantTests is StdInvariant, Test {
    // -------------------------------------------------------------------
    //  State
    // -------------------------------------------------------------------

    BackedToken public token;
    SecureMintPolicy public policy;
    TreasuryVault public vault;
    EmergencyPause public ep;
    MockOracle public oracle;
    MockERC20 public collateral;
    InvariantHandler public handler;

    address public admin = makeAddr("admin");
    address public operator = makeAddr("operator");
    address public guardian = makeAddr("guardian");
    address public treasurer = makeAddr("treasurer");
    address public user = makeAddr("user");

    uint256 public constant GLOBAL_CAP = 10_000_000e18;
    uint256 public constant EPOCH_CAP = 1_000_000e18;
    uint256 public constant EPOCH_DURATION = 24 hours;
    uint256 public constant MAX_STALENESS = 3600;
    uint256 public constant MAX_DEVIATION = 500;
    uint256 public constant TIMELOCK_DELAY = 2 days;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");

    // -------------------------------------------------------------------
    //  Setup
    // -------------------------------------------------------------------

    function setUp() public {
        // Deploy core contracts
        token = new BackedToken("USD Backed Token", "USDX", 18, admin);
        oracle = new MockOracle();
        oracle.setBackingAmount(100_000_000e18);
        oracle.setLastUpdate(block.timestamp);

        collateral = new MockERC20("USD Coin", "USDC", 6);

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

        vault = new TreasuryVault(
            address(collateral),
            address(token),
            address(oracle),
            admin
        );

        ep = new EmergencyPause(
            admin,
            3 days,
            1 hours,
            address(token),
            address(policy)
        );

        // Wire up roles
        vm.startPrank(admin);

        // Token roles
        token.grantRole(MINTER_ROLE, address(policy));
        token.grantRole(PAUSER_ROLE, address(ep));

        // Policy roles
        policy.grantRole(OPERATOR_ROLE, operator);
        policy.grantRole(GUARDIAN_ROLE, guardian);
        policy.setEmergencyPause(address(ep));

        // EmergencyPause roles
        ep.grantRole(keccak256("GUARDIAN_ROLE"), guardian);
        ep.grantRole(keccak256("DAO_ROLE"), admin);

        // Vault roles - relax tier constraints for handler deposits
        vault.grantRole(TREASURER_ROLE, treasurer);
        vault.grantRole(OPERATOR_ROLE, operator);
        vault.configureTier(TreasuryVault.Tier.T0_HOT, 0, 10_000, type(uint256).max, 0);
        vault.configureTier(TreasuryVault.Tier.T1_WARM, 0, 10_000, type(uint256).max, 0);
        vault.configureTier(TreasuryVault.Tier.T2_COLD, 0, 10_000, type(uint256).max, 0);
        vault.configureTier(TreasuryVault.Tier.T3_RWA, 0, 10_000, type(uint256).max, 0);

        vm.stopPrank();

        // Fund treasurer with collateral
        collateral.mint(treasurer, 1_000_000_000e6); // 1B USDC
        vm.prank(treasurer);
        collateral.approve(address(vault), type(uint256).max);

        // Deploy handler
        handler = new InvariantHandler(
            token,
            policy,
            vault,
            ep,
            oracle,
            collateral,
            admin,
            operator,
            guardian,
            treasurer,
            user
        );

        // Target only the handler for invariant testing
        targetContract(address(handler));

        // Target specific functions on the handler
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = InvariantHandler.mint.selector;
        selectors[1] = InvariantHandler.burn.selector;
        selectors[2] = InvariantHandler.togglePause.selector;
        selectors[3] = InvariantHandler.deposit.selector;
        selectors[4] = InvariantHandler.withdraw.selector;
        selectors[5] = InvariantHandler.warpTime.selector;

        targetSelector(FuzzSelector({
            addr: address(handler),
            selectors: selectors
        }));
    }

    // -------------------------------------------------------------------
    //  Invariants
    // -------------------------------------------------------------------

    /**
     * @notice Oracle backing must always cover the total token supply.
     * @dev This is the fundamental safety property of the protocol.
     */
    function invariant_backingCoversSupply() public view {
        uint256 backing = oracle.getBackingAmount();
        uint256 supply = token.totalSupply();
        assertGe(backing, supply, "INVARIANT VIOLATED: backing < totalSupply");
    }

    /**
     * @notice Tokens minted in the current epoch must not exceed the epoch cap.
     */
    function invariant_mintBounded() public view {
        assertLe(
            policy.epochMinted(),
            policy.epochMintCap(),
            "INVARIANT VIOLATED: epochMinted > epochMintCap"
        );
    }

    /**
     * @notice Total supply must not exceed the global supply cap (if non-zero).
     */
    function invariant_supplyBounded() public view {
        uint256 cap = policy.globalSupplyCap();
        if (cap > 0) {
            assertLe(
                token.totalSupply(),
                cap,
                "INVARIANT VIOLATED: totalSupply > globalSupplyCap"
            );
        }
    }

    /**
     * @notice Only the SecureMintPolicy should have the MINTER_ROLE on the token.
     * @dev This ensures no bypass path exists for minting.
     */
    function invariant_noBypassPath() public view {
        assertTrue(
            token.hasRole(MINTER_ROLE, address(policy)),
            "INVARIANT VIOLATED: policy lost MINTER_ROLE"
        );

        // Verify no other known actor has MINTER_ROLE
        assertFalse(
            token.hasRole(MINTER_ROLE, admin),
            "INVARIANT VIOLATED: admin has MINTER_ROLE (bypass path)"
        );
        assertFalse(
            token.hasRole(MINTER_ROLE, operator),
            "INVARIANT VIOLATED: operator has MINTER_ROLE (bypass path)"
        );
        assertFalse(
            token.hasRole(MINTER_ROLE, guardian),
            "INVARIANT VIOLATED: guardian has MINTER_ROLE (bypass path)"
        );
        assertFalse(
            token.hasRole(MINTER_ROLE, user),
            "INVARIANT VIOLATED: user has MINTER_ROLE (bypass path)"
        );
    }

    /**
     * @notice When the policy is paused, any mint attempt must revert.
     * @dev We verify this by checking that if the policy is paused,
     *      the handler's mint calls should have reverted.
     */
    function invariant_pauseBlocksMint() public {
        if (policy.paused()) {
            // Attempt a mint and confirm it reverts
            vm.prank(operator);
            vm.expectRevert();
            policy.mint(user, 1e18);
        }
    }

    /**
     * @notice Ghost variable consistency: totalMinted - totalBurned == totalSupply.
     */
    function invariant_ghostVariableConsistency() public view {
        uint256 expectedSupply = handler.totalMinted() - handler.totalBurned();
        assertEq(
            token.totalSupply(),
            expectedSupply,
            "INVARIANT VIOLATED: ghost supply mismatch"
        );
    }

    // -------------------------------------------------------------------
    //  Call Summary (for debugging)
    // -------------------------------------------------------------------

    function invariant_callSummary() public view {
        // This invariant always passes; it just logs stats for debugging.
        // Uncomment console.log lines when running with verbosity.
        // console.log("Successful mints:", handler.mintCallCount());
        // console.log("Reverted mints:", handler.mintRevertCount());
        // console.log("Total supply:", token.totalSupply());
        // console.log("Epoch minted:", policy.epochMinted());
        // console.log("Current pause level:", uint8(ep.currentLevel()));
    }
}
