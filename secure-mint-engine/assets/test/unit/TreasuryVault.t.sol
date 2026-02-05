// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/TreasuryVault.sol";
import "../../contracts/BackedToken.sol";
import "../mocks/MockOracle.sol";
import "../mocks/MockERC20.sol";

/**
 * @title TreasuryVaultTest
 * @notice Unit tests for the TreasuryVault 4-tier collateral management system.
 */
contract TreasuryVaultTest is Test {
    // -------------------------------------------------------------------
    //  State
    // -------------------------------------------------------------------

    TreasuryVault public vault;
    BackedToken public backedToken;
    MockERC20 public collateral;
    MockOracle public oracle;

    address public admin = makeAddr("admin");
    address public treasurer = makeAddr("treasurer");
    address public vaultOperator = makeAddr("vaultOperator");
    address public user = makeAddr("user");

    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // -------------------------------------------------------------------
    //  Setup
    // -------------------------------------------------------------------

    function setUp() public {
        // Deploy collateral token (e.g. USDC mock)
        collateral = new MockERC20("USD Coin", "USDC", 6);

        // Deploy backed token
        backedToken = new BackedToken("USD Backed Token", "USDX", 18, admin);

        // Deploy oracle
        oracle = new MockOracle();

        // Deploy vault
        vault = new TreasuryVault(
            address(collateral),
            address(backedToken),
            address(oracle),
            admin
        );

        // Grant roles
        vm.startPrank(admin);
        vault.grantRole(TREASURER_ROLE, treasurer);
        vault.grantRole(OPERATOR_ROLE, vaultOperator);
        vm.stopPrank();

        // Fund the treasurer with collateral for deposits
        collateral.mint(treasurer, 100_000_000e6); // 100M USDC

        // Approve vault to spend treasurer's collateral
        vm.prank(treasurer);
        collateral.approve(address(vault), type(uint256).max);
    }

    // -------------------------------------------------------------------
    //  Helper: Seed tiers with balanced allocation
    // -------------------------------------------------------------------

    /**
     * @dev Seeds the vault with a balanced allocation across all 4 tiers.
     *      Total: 10,000,000 USDC
     *      T0_HOT:  750,000 (7.5%)  - within [5%, 10%]
     *      T1_WARM: 2,000,000 (20%) - within [15%, 25%]
     *      T2_COLD: 5,500,000 (55%) - within [50%, 60%]
     *      T3_RWA:  1,750,000 (17.5%) - within [10%, 20%]
     */
    function _seedBalanced() internal {
        vm.startPrank(treasurer);
        // Deposit in order that respects max allocation constraints
        // When vault is empty, first deposit gets 100% allocation.
        // We need to configure tiers more permissively for seeding, then
        // we verify post-state.
        vm.stopPrank();

        // Temporarily relax tier constraints for seeding
        vm.startPrank(admin);
        vault.configureTier(TreasuryVault.Tier.T0_HOT, 0, 10_000, type(uint256).max, 0);
        vault.configureTier(TreasuryVault.Tier.T1_WARM, 0, 10_000, type(uint256).max, 0);
        vault.configureTier(TreasuryVault.Tier.T2_COLD, 0, 10_000, type(uint256).max, 0);
        vault.configureTier(TreasuryVault.Tier.T3_RWA, 0, 10_000, type(uint256).max, 0);
        vm.stopPrank();

        vm.startPrank(treasurer);
        vault.deposit(TreasuryVault.Tier.T0_HOT, 750_000e6);
        vault.deposit(TreasuryVault.Tier.T1_WARM, 2_000_000e6);
        vault.deposit(TreasuryVault.Tier.T2_COLD, 5_500_000e6);
        vault.deposit(TreasuryVault.Tier.T3_RWA, 1_750_000e6);
        vm.stopPrank();

        // Restore default tier constraints
        vm.startPrank(admin);
        vault.configureTier(TreasuryVault.Tier.T0_HOT, 500, 1_000, type(uint256).max, 0);
        vault.configureTier(TreasuryVault.Tier.T1_WARM, 1_500, 2_500, type(uint256).max, 1 hours);
        vault.configureTier(TreasuryVault.Tier.T2_COLD, 5_000, 6_000, type(uint256).max, 24 hours);
        vault.configureTier(TreasuryVault.Tier.T3_RWA, 1_000, 2_000, type(uint256).max, 72 hours);
        vm.stopPrank();
    }

    // -------------------------------------------------------------------
    //  Deposit Tests
    // -------------------------------------------------------------------

    function test_DepositToTier() public {
        // Relax constraints for initial deposit
        vm.prank(admin);
        vault.configureTier(TreasuryVault.Tier.T0_HOT, 0, 10_000, type(uint256).max, 0);

        vm.prank(treasurer);
        vault.deposit(TreasuryVault.Tier.T0_HOT, 1_000e6);

        assertEq(vault.tierBalance(TreasuryVault.Tier.T0_HOT), 1_000e6);
        assertEq(vault.totalBalance(), 1_000e6);
        assertEq(collateral.balanceOf(address(vault)), 1_000e6);
    }

    function test_DepositMultipleTiers() public {
        _seedBalanced();

        assertEq(vault.tierBalance(TreasuryVault.Tier.T0_HOT), 750_000e6);
        assertEq(vault.tierBalance(TreasuryVault.Tier.T1_WARM), 2_000_000e6);
        assertEq(vault.tierBalance(TreasuryVault.Tier.T2_COLD), 5_500_000e6);
        assertEq(vault.tierBalance(TreasuryVault.Tier.T3_RWA), 1_750_000e6);
        assertEq(vault.totalBalance(), 10_000_000e6);
    }

    function test_DepositRevertsZeroAmount() public {
        vm.prank(treasurer);
        vm.expectRevert(TreasuryVault.ZeroAmount.selector);
        vault.deposit(TreasuryVault.Tier.T0_HOT, 0);
    }

    function test_DepositRevertsWithoutTreasurerRole() public {
        vm.prank(user);
        vm.expectRevert();
        vault.deposit(TreasuryVault.Tier.T0_HOT, 1_000e6);
    }

    // -------------------------------------------------------------------
    //  Withdrawal Tests
    // -------------------------------------------------------------------

    function test_WithdrawFromTier() public {
        _seedBalanced();

        // T0_HOT has no cooldown, withdraw is immediate
        vm.prank(treasurer);
        vault.withdraw(TreasuryVault.Tier.T0_HOT, 50_000e6, treasurer);

        assertEq(vault.tierBalance(TreasuryVault.Tier.T0_HOT), 700_000e6);
    }

    function test_WithdrawRevertsInsufficientBalance() public {
        _seedBalanced();

        vm.prank(treasurer);
        vm.expectRevert(
            abi.encodeWithSelector(
                TreasuryVault.InsufficientBalance.selector,
                750_000e6,   // available in T0_HOT
                999_000_000e6 // requested
            )
        );
        vault.withdraw(TreasuryVault.Tier.T0_HOT, 999_000_000e6, treasurer);
    }

    function test_WithdrawRevertsZeroAddress() public {
        _seedBalanced();

        vm.prank(treasurer);
        vm.expectRevert(TreasuryVault.ZeroAddress.selector);
        vault.withdraw(TreasuryVault.Tier.T0_HOT, 1_000e6, address(0));
    }

    function test_WithdrawRevertsZeroAmount() public {
        _seedBalanced();

        vm.prank(treasurer);
        vm.expectRevert(TreasuryVault.ZeroAmount.selector);
        vault.withdraw(TreasuryVault.Tier.T0_HOT, 0, treasurer);
    }

    // -------------------------------------------------------------------
    //  Withdrawal Cooldown Tests
    // -------------------------------------------------------------------

    function test_WithdrawCooldown() public {
        _seedBalanced();

        // T1_WARM has a 1-hour cooldown
        vm.prank(treasurer);
        vault.withdraw(TreasuryVault.Tier.T1_WARM, 50_000e6, treasurer);

        // Second withdrawal in same block should revert due to cooldown
        vm.prank(treasurer);
        vm.expectRevert();
        vault.withdraw(TreasuryVault.Tier.T1_WARM, 50_000e6, treasurer);

        // After cooldown elapses, withdrawal should succeed
        vm.warp(block.timestamp + 1 hours);

        vm.prank(treasurer);
        vault.withdraw(TreasuryVault.Tier.T1_WARM, 50_000e6, treasurer);

        assertEq(vault.tierBalance(TreasuryVault.Tier.T1_WARM), 1_900_000e6);
    }

    function test_WithdrawCooldownColdTier() public {
        _seedBalanced();

        vm.prank(treasurer);
        vault.withdraw(TreasuryVault.Tier.T2_COLD, 100_000e6, treasurer);

        // Should revert before 24h cooldown
        vm.warp(block.timestamp + 23 hours);

        vm.prank(treasurer);
        vm.expectRevert();
        vault.withdraw(TreasuryVault.Tier.T2_COLD, 100_000e6, treasurer);

        // After 24h should work
        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(treasurer);
        vault.withdraw(TreasuryVault.Tier.T2_COLD, 100_000e6, treasurer);
    }

    // -------------------------------------------------------------------
    //  Rebalance Tests
    // -------------------------------------------------------------------

    function test_Rebalance() public {
        _seedBalanced();

        // Rebalance from T2_COLD to T0_HOT (within allocation bounds)
        // Moving a small amount should keep both tiers within their bounds
        vm.prank(vaultOperator);
        vault.rebalance(
            TreasuryVault.Tier.T2_COLD,
            TreasuryVault.Tier.T0_HOT,
            100_000e6
        );

        assertEq(vault.tierBalance(TreasuryVault.Tier.T2_COLD), 5_400_000e6);
        assertEq(vault.tierBalance(TreasuryVault.Tier.T0_HOT), 850_000e6);
        // Total remains the same
        assertEq(vault.totalBalance(), 10_000_000e6);
    }

    function test_RebalanceRevertsZeroAmount() public {
        _seedBalanced();

        vm.prank(vaultOperator);
        vm.expectRevert(TreasuryVault.ZeroAmount.selector);
        vault.rebalance(TreasuryVault.Tier.T0_HOT, TreasuryVault.Tier.T1_WARM, 0);
    }

    function test_RebalanceRevertsInsufficientBalance() public {
        _seedBalanced();

        vm.prank(vaultOperator);
        vm.expectRevert(
            abi.encodeWithSelector(
                TreasuryVault.InsufficientBalance.selector,
                750_000e6,
                999_000_000e6
            )
        );
        vault.rebalance(
            TreasuryVault.Tier.T0_HOT,
            TreasuryVault.Tier.T1_WARM,
            999_000_000e6
        );
    }

    // -------------------------------------------------------------------
    //  Redemption Tests
    // -------------------------------------------------------------------

    function test_RedeemWithSlippageProtection() public {
        _seedBalanced();

        // Mint backed tokens to the user (simulate)
        vm.prank(admin);
        backedToken.grantRole(MINTER_ROLE, admin);

        vm.prank(admin);
        backedToken.mint(user, 1_000e18);

        // User approves vault to burn their tokens
        vm.prank(user);
        backedToken.approve(address(vault), 100e18);

        // Calculate expected collateral out
        // totalCollateral = 10,000,000e6, totalSupply = 1,000e18
        // collateralOut = (100e18 * 10_000_000e6) / 1_000e18 = 1_000_000e6
        uint256 expectedCollateral = (100e18 * 10_000_000e6) / 1_000e18;

        uint256 userCollateralBefore = collateral.balanceOf(user);

        vm.prank(user);
        vault.redeem(100e18, expectedCollateral);

        assertEq(
            collateral.balanceOf(user) - userCollateralBefore,
            expectedCollateral
        );
        assertEq(backedToken.balanceOf(user), 900e18);
    }

    function test_RedeemRevertsSlippageExceeded() public {
        _seedBalanced();

        vm.prank(admin);
        backedToken.grantRole(MINTER_ROLE, admin);

        vm.prank(admin);
        backedToken.mint(user, 1_000e18);

        vm.prank(user);
        backedToken.approve(address(vault), 100e18);

        // Demand more collateral than would be returned
        uint256 tooMuch = 999_999_999e6;

        vm.prank(user);
        vm.expectRevert("TreasuryVault: slippage exceeded");
        vault.redeem(100e18, tooMuch);
    }

    function test_RedeemRevertsZeroAmount() public {
        vm.prank(user);
        vm.expectRevert(TreasuryVault.ZeroAmount.selector);
        vault.redeem(0, 0);
    }

    // -------------------------------------------------------------------
    //  Allocation Constraint Tests
    // -------------------------------------------------------------------

    function test_RevertBelowMinAllocation() public {
        _seedBalanced();

        // Trying to withdraw almost all of T0_HOT would bring its allocation
        // below the 5% minimum. T0_HOT has 750,000 of 10,000,000 total (7.5%).
        // Withdrawing 700,000 would leave 50,000 of 9,300,000 total = 0.54%
        vm.prank(treasurer);
        vm.expectRevert();
        vault.withdraw(TreasuryVault.Tier.T0_HOT, 700_000e6, treasurer);
    }

    function test_RevertAboveMaxAllocation() public {
        _seedBalanced();

        // T0_HOT max is 10% (1,000 bps). Currently 750,000 of 10,000,000 (7.5%).
        // Depositing enough to exceed 10% should revert.
        // Trying to deposit 500,000 would make T0_HOT = 1,250,000 of 10,500,000 = 11.9%
        vm.prank(treasurer);
        vm.expectRevert();
        vault.deposit(TreasuryVault.Tier.T0_HOT, 500_000e6);
    }

    function test_RebalanceRevertsBelowMinAllocation() public {
        _seedBalanced();

        // T0_HOT has 750,000. Moving 500,000 out would leave 250,000 of
        // 10,000,000 = 2.5%, below the 5% minimum.
        vm.prank(vaultOperator);
        vm.expectRevert();
        vault.rebalance(
            TreasuryVault.Tier.T0_HOT,
            TreasuryVault.Tier.T2_COLD,
            500_000e6
        );
    }

    function test_RebalanceRevertsAboveMaxAllocation() public {
        _seedBalanced();

        // T0_HOT max is 10%. Moving 500,000 from T2_COLD to T0_HOT would make
        // T0_HOT = 1,250,000 of 10,000,000 = 12.5%, above 10% max.
        vm.prank(vaultOperator);
        vm.expectRevert();
        vault.rebalance(
            TreasuryVault.Tier.T2_COLD,
            TreasuryVault.Tier.T0_HOT,
            500_000e6
        );
    }

    // -------------------------------------------------------------------
    //  View Function Tests
    // -------------------------------------------------------------------

    function test_TotalBalance() public {
        _seedBalanced();
        assertEq(vault.totalBalance(), 10_000_000e6);
    }

    function test_TierAllocationBps() public {
        _seedBalanced();

        uint256 hotBps = vault.tierAllocationBps(TreasuryVault.Tier.T0_HOT);
        // 750,000 / 10,000,000 * 10,000 = 750 bps (7.5%)
        assertEq(hotBps, 750);
    }

    function test_HealthFactorFullyBacked() public {
        _seedBalanced();

        // Mint backed tokens with supply = collateral value (assume 1:1 for test)
        vm.prank(admin);
        backedToken.grantRole(MINTER_ROLE, admin);

        vm.prank(admin);
        backedToken.mint(user, 10_000_000e6); // Same as collateral

        // Health factor should be 10,000 bps (100%)
        assertEq(vault.healthFactor(), 10_000);
    }

    // -------------------------------------------------------------------
    //  Pause Tests
    // -------------------------------------------------------------------

    function test_DepositWhilePaused_Reverts() public {
        vm.prank(admin);
        vault.pause();

        vm.prank(treasurer);
        vm.expectRevert();
        vault.deposit(TreasuryVault.Tier.T0_HOT, 1_000e6);
    }

    function test_WithdrawWhilePaused_Reverts() public {
        _seedBalanced();

        vm.prank(admin);
        vault.pause();

        vm.prank(treasurer);
        vm.expectRevert();
        vault.withdraw(TreasuryVault.Tier.T0_HOT, 1_000e6, treasurer);
    }

    // -------------------------------------------------------------------
    //  Configuration Tests
    // -------------------------------------------------------------------

    function test_ConfigureTier() public {
        vm.prank(admin);
        vault.configureTier(TreasuryVault.Tier.T0_HOT, 200, 1_500, 50_000e6, 30 minutes);

        (uint256 minBps, uint256 maxBps, uint256 limit, uint256 cooldown,,) =
            vault.tiers(TreasuryVault.Tier.T0_HOT);

        assertEq(minBps, 200);
        assertEq(maxBps, 1_500);
        assertEq(limit, 50_000e6);
        assertEq(cooldown, 30 minutes);
    }

    function test_ConfigureTierRevertsMinGreaterThanMax() public {
        vm.prank(admin);
        vm.expectRevert("TreasuryVault: min > max");
        vault.configureTier(TreasuryVault.Tier.T0_HOT, 5_000, 1_000, type(uint256).max, 0);
    }

    function test_ConfigureTierRevertsMaxAbove100Percent() public {
        vm.prank(admin);
        vm.expectRevert("TreasuryVault: max > 100%");
        vault.configureTier(TreasuryVault.Tier.T0_HOT, 0, 10_001, type(uint256).max, 0);
    }
}
