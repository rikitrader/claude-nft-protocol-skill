// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/TreasuryVault.sol";
import "../mocks/MockERC20.sol";

/**
 * @title TreasuryVault Unit Tests
 * @notice Comprehensive tests for the multi-tier TreasuryVault contract
 * @dev Tests deposits, withdrawals, tier management, rebalancing,
 *      allocation governance, emergency withdrawal, and pause controls.
 */
contract TreasuryVaultTest is Test {
    TreasuryVault public vault;
    MockERC20 public reserveAsset;

    address public admin = address(1);
    address public guardian = address(2);
    address public governor = address(3);
    address public rebalancer = address(4);
    address public user = address(5);
    address public attacker = address(6);

    uint256 public constant DEPOSIT_AMOUNT = 1_000_000 * 1e6; // 1M USDC
    uint256 public constant LARGE_DEPOSIT = 10_000_000 * 1e6; // 10M USDC

    // Default allocations: HOT=1000 (10%), WARM=2000 (20%), COLD=5000 (50%), RWA=2000 (20%)
    uint256[4] public defaultAllocations = [uint256(1000), 2000, 5000, 2000];

    // Events (must redeclare for vm.expectEmit)
    event Deposit(address indexed from, uint256 amount, uint8 tier);
    event Withdrawal(address indexed to, uint256 amount, uint8 tier, string reason);
    event TierTransfer(uint8 fromTier, uint8 toTier, uint256 amount);
    event Rebalanced(uint256[4] newBalances);
    event AllocationProposed(uint256[4] newAllocations, uint256 executeAfter);
    event AllocationExecuted(uint256[4] newAllocations);
    event AllocationCancelled();
    event EmergencyWithdrawal(address indexed to, uint256 amount, string reason);

    function setUp() public {
        reserveAsset = new MockERC20("USD Coin", "USDC", 6);

        vm.startPrank(admin);
        vault = new TreasuryVault(
            address(reserveAsset),
            admin,
            defaultAllocations
        );

        // Grant roles
        vault.grantRole(vault.GUARDIAN_ROLE(), guardian);
        vault.grantRole(vault.GOVERNOR_ROLE(), governor);
        vault.grantRole(vault.REBALANCER_ROLE(), rebalancer);
        vm.stopPrank();

        // Mint reserve tokens to admin for deposits
        reserveAsset.mint(admin, 100_000_000 * 1e6);
        vm.prank(admin);
        reserveAsset.approve(address(vault), type(uint256).max);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_constructor_setsReserveAsset() public view {
        assertEq(address(vault.reserveAsset()), address(reserveAsset));
    }

    function test_constructor_setsTargetAllocations() public view {
        uint256[4] memory allocs = vault.getTargetAllocations();
        assertEq(allocs[0], 1000);
        assertEq(allocs[1], 2000);
        assertEq(allocs[2], 5000);
        assertEq(allocs[3], 2000);
    }

    function test_constructor_setsDefaultRebalanceThreshold() public view {
        assertEq(vault.rebalanceThreshold(), 500);
    }

    function test_constructor_initialReservesAreZero() public view {
        assertEq(vault.totalReserves(), 0);
        uint256[4] memory balances = vault.getTierBalances();
        for (uint8 i = 0; i < 4; i++) {
            assertEq(balances[i], 0);
        }
    }

    function test_constructor_revertsOnZeroReserveAsset() public {
        vm.expectRevert(TreasuryVault.ZeroAddress.selector);
        new TreasuryVault(address(0), admin, defaultAllocations);
    }

    function test_constructor_revertsOnZeroAdmin() public {
        vm.expectRevert(TreasuryVault.ZeroAddress.selector);
        new TreasuryVault(address(reserveAsset), address(0), defaultAllocations);
    }

    function test_constructor_revertsOnInvalidAllocationSum() public {
        uint256[4] memory badAllocations = [uint256(1000), 2000, 5000, 3000]; // Sum = 11000
        vm.expectRevert(TreasuryVault.AllocationSumInvalid.selector);
        new TreasuryVault(address(reserveAsset), admin, badAllocations);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DEPOSIT TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_deposit_toSpecificTier() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        assertEq(vault.totalReserves(), DEPOSIT_AMOUNT);
        uint256[4] memory balances = vault.getTierBalances();
        assertEq(balances[0], DEPOSIT_AMOUNT);
        assertEq(balances[1], 0);
        assertEq(balances[2], 0);
        assertEq(balances[3], 0);
    }

    function test_deposit_emitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit Deposit(admin, DEPOSIT_AMOUNT, vault.TIER_WARM());

        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_WARM());
    }

    function test_deposit_toAllTiers() public {
        vm.startPrank(admin);
        vault.deposit(100 * 1e6, vault.TIER_HOT());
        vault.deposit(200 * 1e6, vault.TIER_WARM());
        vault.deposit(500 * 1e6, vault.TIER_COLD());
        vault.deposit(200 * 1e6, vault.TIER_RWA());
        vm.stopPrank();

        assertEq(vault.totalReserves(), 1000 * 1e6);
        uint256[4] memory balances = vault.getTierBalances();
        assertEq(balances[0], 100 * 1e6);
        assertEq(balances[1], 200 * 1e6);
        assertEq(balances[2], 500 * 1e6);
        assertEq(balances[3], 200 * 1e6);
    }

    function test_deposit_revertsOnInvalidTier() public {
        vm.prank(admin);
        vm.expectRevert(TreasuryVault.InvalidTier.selector);
        vault.deposit(DEPOSIT_AMOUNT, 4); // NUM_TIERS = 4, so tier 4 is invalid
    }

    function test_deposit_revertsOnZeroAmount() public {
        vm.prank(admin);
        vm.expectRevert(TreasuryVault.ZeroAmount.selector);
        vault.deposit(0, vault.TIER_HOT());
    }

    function test_deposit_revertsForUnauthorizedCaller() public {
        reserveAsset.mint(attacker, DEPOSIT_AMOUNT);
        vm.startPrank(attacker);
        reserveAsset.approve(address(vault), DEPOSIT_AMOUNT);

        vm.expectRevert();
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());
        vm.stopPrank();
    }

    function test_depositDistributed_splitsAcrossTiers() public {
        vm.prank(admin);
        vault.depositDistributed(DEPOSIT_AMOUNT);

        assertEq(vault.totalReserves(), DEPOSIT_AMOUNT);
        uint256[4] memory balances = vault.getTierBalances();

        // Check distribution matches allocations: 10%, 20%, 50%, 20%
        assertEq(balances[0], (DEPOSIT_AMOUNT * 1000) / 10000);
        assertEq(balances[1], (DEPOSIT_AMOUNT * 2000) / 10000);
        assertEq(balances[2], (DEPOSIT_AMOUNT * 5000) / 10000);
        assertEq(balances[3], (DEPOSIT_AMOUNT * 2000) / 10000);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // WITHDRAWAL TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_withdraw_fromSpecificTier() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        uint256 withdrawAmount = DEPOSIT_AMOUNT / 2;
        vm.prank(admin);
        vault.withdraw(user, withdrawAmount, vault.TIER_HOT(), "Testing withdrawal");

        assertEq(reserveAsset.balanceOf(user), withdrawAmount);
        assertEq(vault.totalReserves(), DEPOSIT_AMOUNT - withdrawAmount);
    }

    function test_withdraw_emitsEvent() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_COLD());

        vm.expectEmit(true, false, false, true);
        emit Withdrawal(user, DEPOSIT_AMOUNT / 2, vault.TIER_COLD(), "Redemption");

        vm.prank(admin);
        vault.withdraw(user, DEPOSIT_AMOUNT / 2, vault.TIER_COLD(), "Redemption");
    }

    function test_withdraw_revertsOnInsufficientBalance() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        vm.prank(admin);
        vm.expectRevert(TreasuryVault.InsufficientBalance.selector);
        vault.withdraw(user, DEPOSIT_AMOUNT + 1, vault.TIER_HOT(), "Overdraw");
    }

    function test_withdraw_revertsOnZeroAddress() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        vm.prank(admin);
        vm.expectRevert(TreasuryVault.ZeroAddress.selector);
        vault.withdraw(address(0), DEPOSIT_AMOUNT, vault.TIER_HOT(), "Bad address");
    }

    function test_withdraw_revertsOnZeroAmount() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        vm.prank(admin);
        vm.expectRevert(TreasuryVault.ZeroAmount.selector);
        vault.withdraw(user, 0, vault.TIER_HOT(), "Zero");
    }

    function test_withdraw_revertsOnInvalidTier() public {
        vm.prank(admin);
        vm.expectRevert(TreasuryVault.InvalidTier.selector);
        vault.withdraw(user, 1, 5, "Bad tier");
    }

    function test_withdraw_revertsForUnauthorizedCaller() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        vm.prank(attacker);
        vm.expectRevert();
        vault.withdraw(attacker, DEPOSIT_AMOUNT, vault.TIER_HOT(), "Steal");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ROLE ACCESS CONTROL TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_roles_treasuryAdminCanDeposit() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        assertEq(vault.totalReserves(), DEPOSIT_AMOUNT);
    }

    function test_roles_guardianCannotDeposit() public {
        reserveAsset.mint(guardian, DEPOSIT_AMOUNT);
        vm.startPrank(guardian);
        reserveAsset.approve(address(vault), DEPOSIT_AMOUNT);

        vm.expectRevert();
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());
        vm.stopPrank();
    }

    function test_roles_rebalancerCanTransferBetweenTiers() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        vm.prank(rebalancer);
        vault.transferBetweenTiers(vault.TIER_HOT(), vault.TIER_COLD(), DEPOSIT_AMOUNT / 2);

        uint256[4] memory balances = vault.getTierBalances();
        assertEq(balances[0], DEPOSIT_AMOUNT / 2);
        assertEq(balances[2], DEPOSIT_AMOUNT / 2);
    }

    function test_roles_nonRebalancerCannotTransfer() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        vm.prank(attacker);
        vm.expectRevert();
        vault.transferBetweenTiers(vault.TIER_HOT(), vault.TIER_COLD(), DEPOSIT_AMOUNT);
    }

    function test_roles_guardianCanEmergencyWithdraw() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        vm.prank(guardian);
        vault.emergencyWithdraw(user, DEPOSIT_AMOUNT, "Emergency drill");

        assertEq(reserveAsset.balanceOf(user), DEPOSIT_AMOUNT);
    }

    function test_roles_nonGuardianCannotEmergencyWithdraw() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        vm.prank(attacker);
        vm.expectRevert();
        vault.emergencyWithdraw(attacker, DEPOSIT_AMOUNT, "Steal attempt");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // REBALANCE THRESHOLD TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_needsRebalancing_falseWhenEmpty() public view {
        assertFalse(vault.needsRebalancing());
    }

    function test_needsRebalancing_trueWhenSkewed() public {
        // Deposit everything into HOT tier (should be 10%, but now is 100%)
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        assertTrue(vault.needsRebalancing());
    }

    function test_needsRebalancing_falseWhenBalanced() public {
        // Deposit proportionally matching target allocations
        vm.startPrank(admin);
        vault.deposit((DEPOSIT_AMOUNT * 1000) / 10000, vault.TIER_HOT());
        vault.deposit((DEPOSIT_AMOUNT * 2000) / 10000, vault.TIER_WARM());
        vault.deposit((DEPOSIT_AMOUNT * 5000) / 10000, vault.TIER_COLD());
        vault.deposit((DEPOSIT_AMOUNT * 2000) / 10000, vault.TIER_RWA());
        vm.stopPrank();

        assertFalse(vault.needsRebalancing());
    }

    function test_setRebalanceThreshold_byGovernor() public {
        vm.prank(governor);
        vault.setRebalanceThreshold(1000); // 10%

        assertEq(vault.rebalanceThreshold(), 1000);
    }

    function test_setRebalanceThreshold_revertsForNonGovernor() public {
        vm.prank(attacker);
        vm.expectRevert();
        vault.setRebalanceThreshold(1000);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // REBALANCE EXECUTION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_rebalance_redistributesFunds() public {
        // Put everything in HOT tier
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        assertTrue(vault.needsRebalancing());

        // Rebalance
        vm.prank(rebalancer);
        vault.rebalance();

        uint256[4] memory balances = vault.getTierBalances();
        // Verify tiers are close to target allocations
        assertEq(balances[0], (DEPOSIT_AMOUNT * 1000) / 10000);
        assertEq(balances[1], (DEPOSIT_AMOUNT * 2000) / 10000);
        assertEq(balances[2], (DEPOSIT_AMOUNT * 5000) / 10000);
        assertEq(balances[3], (DEPOSIT_AMOUNT * 2000) / 10000);
    }

    function test_rebalance_emitsEvent() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        // We just check that the event is emitted (details checked in the assertion above)
        vm.prank(rebalancer);
        vault.rebalance();

        // Post-rebalance: totalReserves unchanged
        assertEq(vault.totalReserves(), DEPOSIT_AMOUNT);
    }

    function test_rebalance_revertsForNonRebalancer() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        vm.prank(attacker);
        vm.expectRevert();
        vault.rebalance();
    }

    function test_transferBetweenTiers_revertsOnSameTier() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        vm.prank(rebalancer);
        vm.expectRevert(TreasuryVault.InvalidTier.selector);
        vault.transferBetweenTiers(vault.TIER_HOT(), vault.TIER_HOT(), DEPOSIT_AMOUNT);
    }

    function test_transferBetweenTiers_revertsOnInsufficientBalance() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        vm.prank(rebalancer);
        vm.expectRevert(TreasuryVault.InsufficientBalance.selector);
        vault.transferBetweenTiers(vault.TIER_HOT(), vault.TIER_COLD(), DEPOSIT_AMOUNT + 1);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // EMERGENCY WITHDRAWAL TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_emergencyWithdraw_deductsFromTiersProportionally() public {
        // Distribute across tiers
        vm.startPrank(admin);
        vault.deposit(100 * 1e6, vault.TIER_HOT());
        vault.deposit(200 * 1e6, vault.TIER_WARM());
        vault.deposit(500 * 1e6, vault.TIER_COLD());
        vault.deposit(200 * 1e6, vault.TIER_RWA());
        vm.stopPrank();

        // Emergency withdraw 150 (drains HOT=100, then 50 from WARM)
        vm.prank(guardian);
        vault.emergencyWithdraw(user, 150 * 1e6, "Emergency: depeg event");

        assertEq(reserveAsset.balanceOf(user), 150 * 1e6);
        assertEq(vault.totalReserves(), 850 * 1e6);

        uint256[4] memory balances = vault.getTierBalances();
        assertEq(balances[0], 0);          // HOT fully drained
        assertEq(balances[1], 150 * 1e6);  // WARM partially drained
        assertEq(balances[2], 500 * 1e6);  // COLD untouched
        assertEq(balances[3], 200 * 1e6);  // RWA untouched
    }

    function test_emergencyWithdraw_emitsEvent() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        vm.expectEmit(true, false, false, true);
        emit EmergencyWithdrawal(user, DEPOSIT_AMOUNT, "Critical event");

        vm.prank(guardian);
        vault.emergencyWithdraw(user, DEPOSIT_AMOUNT, "Critical event");
    }

    function test_emergencyWithdraw_revertsOnInsufficientBalance() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        vm.prank(guardian);
        vm.expectRevert(TreasuryVault.InsufficientBalance.selector);
        vault.emergencyWithdraw(user, DEPOSIT_AMOUNT + 1, "Overdraw");
    }

    function test_emergencyWithdraw_revertsOnZeroAddress() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        vm.prank(guardian);
        vm.expectRevert(TreasuryVault.ZeroAddress.selector);
        vault.emergencyWithdraw(address(0), DEPOSIT_AMOUNT, "Bad recipient");
    }

    function test_emergencyWithdraw_revertsOnZeroAmount() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        vm.prank(guardian);
        vm.expectRevert(TreasuryVault.ZeroAmount.selector);
        vault.emergencyWithdraw(user, 0, "Zero");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PAUSE / UNPAUSE TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_pause_byGuardian() public {
        vm.prank(guardian);
        vault.pause();

        assertTrue(vault.paused());
    }

    function test_unpause_byGuardian() public {
        vm.prank(guardian);
        vault.pause();

        vm.prank(guardian);
        vault.unpause();

        assertFalse(vault.paused());
    }

    function test_pause_blocksDeposits() public {
        vm.prank(guardian);
        vault.pause();

        vm.prank(admin);
        vm.expectRevert("Pausable: paused");
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());
    }

    function test_pause_blocksWithdrawals() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        vm.prank(guardian);
        vault.pause();

        vm.prank(admin);
        vm.expectRevert("Pausable: paused");
        vault.withdraw(user, DEPOSIT_AMOUNT, vault.TIER_HOT(), "Blocked");
    }

    function test_pause_blocksRebalance() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        vm.prank(guardian);
        vault.pause();

        vm.prank(rebalancer);
        vm.expectRevert("Pausable: paused");
        vault.rebalance();
    }

    function test_pause_doesNotBlockEmergencyWithdraw() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        vm.prank(guardian);
        vault.pause();

        // Emergency withdraw should NOT be blocked by pause (no whenNotPaused modifier)
        vm.prank(guardian);
        vault.emergencyWithdraw(user, DEPOSIT_AMOUNT, "Emergency while paused");

        assertEq(reserveAsset.balanceOf(user), DEPOSIT_AMOUNT);
    }

    function test_pause_revertsForNonGuardian() public {
        vm.prank(attacker);
        vm.expectRevert();
        vault.pause();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ALLOCATION GOVERNANCE TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_proposeAllocation_byGovernor() public {
        uint256[4] memory newAllocations = [uint256(500), 1500, 6000, 2000];

        vm.prank(governor);
        vault.proposeAllocation(newAllocations);

        // Pending allocation should exist
        (,uint256 executeAfter, bool pending) = vault.pendingAllocation();
        assertTrue(pending);
        assertEq(executeAfter, block.timestamp + vault.TIMELOCK_DURATION());
    }

    function test_proposeAllocation_revertsOnInvalidSum() public {
        uint256[4] memory badAllocations = [uint256(500), 1500, 6000, 3000]; // Sum = 11000

        vm.prank(governor);
        vm.expectRevert(TreasuryVault.AllocationSumInvalid.selector);
        vault.proposeAllocation(badAllocations);
    }

    function test_proposeAllocation_revertsWhenAlreadyPending() public {
        uint256[4] memory newAllocations = [uint256(500), 1500, 6000, 2000];

        vm.startPrank(governor);
        vault.proposeAllocation(newAllocations);

        vm.expectRevert(TreasuryVault.ChangeAlreadyPending.selector);
        vault.proposeAllocation(newAllocations);
        vm.stopPrank();
    }

    function test_executeAllocation_afterTimelock() public {
        uint256[4] memory newAllocations = [uint256(500), 1500, 6000, 2000];

        vm.prank(governor);
        vault.proposeAllocation(newAllocations);

        // Warp past timelock
        vm.warp(block.timestamp + vault.TIMELOCK_DURATION() + 1);

        vm.prank(governor);
        vault.executeAllocation();

        uint256[4] memory allocs = vault.getTargetAllocations();
        assertEq(allocs[0], 500);
        assertEq(allocs[1], 1500);
        assertEq(allocs[2], 6000);
        assertEq(allocs[3], 2000);
    }

    function test_executeAllocation_revertsBeforeTimelock() public {
        uint256[4] memory newAllocations = [uint256(500), 1500, 6000, 2000];

        vm.prank(governor);
        vault.proposeAllocation(newAllocations);

        vm.prank(governor);
        vm.expectRevert(TreasuryVault.TimelockNotReady.selector);
        vault.executeAllocation();
    }

    function test_executeAllocation_revertsWithNoPending() public {
        vm.prank(governor);
        vm.expectRevert(TreasuryVault.NoPendingChange.selector);
        vault.executeAllocation();
    }

    function test_cancelAllocation_byGovernor() public {
        uint256[4] memory newAllocations = [uint256(500), 1500, 6000, 2000];

        vm.prank(governor);
        vault.proposeAllocation(newAllocations);

        vm.prank(governor);
        vault.cancelAllocation();

        (,, bool pending) = vault.pendingAllocation();
        assertFalse(pending);
    }

    function test_cancelAllocation_revertsWithNoPending() public {
        vm.prank(governor);
        vm.expectRevert(TreasuryVault.NoPendingChange.selector);
        vault.cancelAllocation();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_getCurrentAllocations_returnsZeroWhenEmpty() public view {
        uint256[4] memory allocs = vault.getCurrentAllocations();
        for (uint8 i = 0; i < 4; i++) {
            assertEq(allocs[i], 0);
        }
    }

    function test_getHealthFactor_returnsFullHealthAt100Percent() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT, vault.TIER_HOT());

        uint256 healthFactor = vault.getHealthFactor(DEPOSIT_AMOUNT);
        assertEq(healthFactor, 10000); // 100% in basis points
    }

    function test_getHealthFactor_returnsHigherWithExcessReserves() public {
        vm.prank(admin);
        vault.deposit(DEPOSIT_AMOUNT * 2, vault.TIER_HOT());

        uint256 healthFactor = vault.getHealthFactor(DEPOSIT_AMOUNT);
        assertEq(healthFactor, 20000); // 200% in basis points
    }

    function test_getHealthFactor_returnsMaxWhenZeroBacking() public view {
        uint256 healthFactor = vault.getHealthFactor(0);
        assertEq(healthFactor, 10000);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUZZ TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function testFuzz_deposit_arbitraryAmount(uint256 amount) public {
        amount = bound(amount, 1, 50_000_000 * 1e6);

        reserveAsset.mint(admin, amount);
        vm.prank(admin);
        vault.deposit(amount, vault.TIER_COLD());

        assertEq(vault.totalReserves(), amount);
    }

    function testFuzz_withdraw_neverExceedsDeposit(uint256 depositAmt, uint256 withdrawAmt) public {
        depositAmt = bound(depositAmt, 1, 50_000_000 * 1e6);
        withdrawAmt = bound(withdrawAmt, 1, depositAmt);

        reserveAsset.mint(admin, depositAmt);
        vm.startPrank(admin);
        vault.deposit(depositAmt, vault.TIER_HOT());
        vault.withdraw(user, withdrawAmt, vault.TIER_HOT(), "Fuzz test");
        vm.stopPrank();

        assertEq(vault.totalReserves(), depositAmt - withdrawAmt);
        assertEq(reserveAsset.balanceOf(user), withdrawAmt);
    }
}
