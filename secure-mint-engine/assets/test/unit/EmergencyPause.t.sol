// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/EmergencyPause.sol";
import "../mocks/MockBackingOracle.sol";

/**
 * @title EmergencyPause Unit Tests
 * @notice Comprehensive tests for the 5-level circuit breaker system
 * @dev Tests constructor defaults, level escalation, role access control,
 *      auto-triggers, recovery timelock, event emissions, and view functions.
 */
contract EmergencyPauseTest is Test {
    EmergencyPause public pause;
    MockBackingOracle public oracle;

    address public admin = address(1);
    address public guardian = address(2);
    address public governor = address(3);
    address public monitor = address(4);
    address public attacker = address(5);

    // Events (must redeclare for vm.expectEmit)
    event LevelChanged(
        EmergencyPause.PauseLevel indexed fromLevel,
        EmergencyPause.PauseLevel indexed toLevel,
        EmergencyPause.TriggerReason indexed reason,
        address triggeredBy,
        string details
    );
    event RecoveryRequested(
        EmergencyPause.PauseLevel targetLevel,
        uint256 executeAfter,
        address requestedBy
    );
    event RecoveryExecuted(EmergencyPause.PauseLevel newLevel, address executedBy);
    event RecoveryCancelled(address cancelledBy);
    event AutoTriggerFired(
        EmergencyPause.TriggerReason reason,
        EmergencyPause.PauseLevel newLevel,
        string details
    );
    event ContractRegistered(address indexed contractAddress);
    event ContractUnregistered(address indexed contractAddress);
    event ThresholdUpdated(string thresholdType, uint256 oldValue, uint256 newValue);

    function setUp() public {
        oracle = new MockBackingOracle();

        vm.startPrank(admin);
        pause = new EmergencyPause(admin);

        // Grant roles to specific addresses (admin already has all roles from constructor)
        pause.grantRole(pause.GUARDIAN_ROLE(), guardian);
        pause.grantRole(pause.GOVERNOR_ROLE(), governor);
        pause.grantRole(pause.MONITOR_ROLE(), monitor);
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_constructor_setsNormalLevel() public view {
        assertEq(uint256(pause.currentLevel()), uint256(EmergencyPause.PauseLevel.NORMAL));
    }

    function test_constructor_setsLevelSetAtTimestamp() public view {
        assertEq(pause.levelSetAt(), block.timestamp);
    }

    function test_constructor_grantsAdminAllRoles() public view {
        assertTrue(pause.hasRole(pause.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(pause.hasRole(pause.GUARDIAN_ROLE(), admin));
        assertTrue(pause.hasRole(pause.GOVERNOR_ROLE(), admin));
        assertTrue(pause.hasRole(pause.MONITOR_ROLE(), admin));
    }

    function test_constructor_revertsOnZeroAdmin() public {
        vm.expectRevert(EmergencyPause.ZeroAddress.selector);
        new EmergencyPause(address(0));
    }

    function test_constructor_defaultThresholds() public view {
        assertEq(pause.oracleStalenessThreshold(), 1 hours);
        assertEq(pause.priceDeviationThreshold(), 500); // 5%
        assertEq(pause.reserveDeficitThreshold(), 0);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // LEVEL ESCALATION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_setElevated_byGuardian() public {
        vm.prank(guardian);
        pause.setElevated("Suspicious activity detected");

        assertEq(uint256(pause.currentLevel()), uint256(EmergencyPause.PauseLevel.ELEVATED));
    }

    function test_setRestricted_byGuardian() public {
        vm.prank(guardian);
        pause.setRestricted("Oracle reporting issues");

        assertEq(uint256(pause.currentLevel()), uint256(EmergencyPause.PauseLevel.RESTRICTED));
    }

    function test_setEmergency_byGuardian() public {
        vm.prank(guardian);
        pause.setEmergency("Critical vulnerability found");

        assertEq(uint256(pause.currentLevel()), uint256(EmergencyPause.PauseLevel.EMERGENCY));
    }

    function test_setShutdown_byGuardian() public {
        vm.prank(guardian);
        pause.setShutdown("Complete protocol shutdown");

        assertEq(uint256(pause.currentLevel()), uint256(EmergencyPause.PauseLevel.SHUTDOWN));
    }

    function test_escalateLevel_fromNormalToEmergency() public {
        vm.prank(guardian);
        pause.escalateLevel(
            EmergencyPause.PauseLevel.EMERGENCY,
            EmergencyPause.TriggerReason.EXPLOIT_DETECTED,
            "Exploit in progress"
        );

        assertEq(uint256(pause.currentLevel()), uint256(EmergencyPause.PauseLevel.EMERGENCY));
        assertEq(uint256(pause.currentReason()), uint256(EmergencyPause.TriggerReason.EXPLOIT_DETECTED));
    }

    function test_escalateLevel_revertsOnLowerLevel() public {
        vm.prank(guardian);
        pause.setRestricted("Initial escalation");

        vm.prank(guardian);
        vm.expectRevert(EmergencyPause.CannotEscalateToLowerLevel.selector);
        pause.escalateLevel(
            EmergencyPause.PauseLevel.ELEVATED,
            EmergencyPause.TriggerReason.MANUAL,
            "Try to lower"
        );
    }

    function test_escalateLevel_revertsOnSameLevel() public {
        vm.prank(guardian);
        pause.setElevated("First");

        vm.prank(guardian);
        vm.expectRevert(EmergencyPause.CannotEscalateToLowerLevel.selector);
        pause.escalateLevel(
            EmergencyPause.PauseLevel.ELEVATED,
            EmergencyPause.TriggerReason.MANUAL,
            "Same level"
        );
    }

    function test_setElevated_revertsWhenAlreadyElevatedOrHigher() public {
        vm.prank(guardian);
        pause.setElevated("First");

        vm.prank(guardian);
        vm.expectRevert(EmergencyPause.InvalidLevelTransition.selector);
        pause.setElevated("Second attempt");
    }

    function test_setRestricted_revertsWhenAlreadyRestricted() public {
        vm.prank(guardian);
        pause.setRestricted("First");

        vm.prank(guardian);
        vm.expectRevert(EmergencyPause.InvalidLevelTransition.selector);
        pause.setRestricted("Second attempt");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ROLE ACCESS CONTROL TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_setElevated_revertsForNonGuardian() public {
        vm.prank(attacker);
        vm.expectRevert();
        pause.setElevated("Unauthorized");
    }

    function test_setRestricted_revertsForNonGuardian() public {
        vm.prank(attacker);
        vm.expectRevert();
        pause.setRestricted("Unauthorized");
    }

    function test_setEmergency_revertsForNonGuardian() public {
        vm.prank(attacker);
        vm.expectRevert();
        pause.setEmergency("Unauthorized");
    }

    function test_setShutdown_revertsForNonGuardian() public {
        vm.prank(attacker);
        vm.expectRevert();
        pause.setShutdown("Unauthorized");
    }

    function test_escalateLevel_revertsForMonitorRole() public {
        vm.prank(monitor);
        vm.expectRevert();
        pause.escalateLevel(
            EmergencyPause.PauseLevel.RESTRICTED,
            EmergencyPause.TriggerReason.MANUAL,
            "Monitor cannot escalate"
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // AUTO-TRIGGER: ORACLE UNHEALTHY
    // ═══════════════════════════════════════════════════════════════════════════

    function test_triggerOracleUnhealthy_setsRestricted() public {
        vm.prank(monitor);
        pause.triggerOracleUnhealthy("Chainlink feed stale");

        assertEq(uint256(pause.currentLevel()), uint256(EmergencyPause.PauseLevel.RESTRICTED));
        assertEq(uint256(pause.currentReason()), uint256(EmergencyPause.TriggerReason.ORACLE_UNHEALTHY));
    }

    function test_triggerOracleUnhealthy_emitsAutoTriggerEvent() public {
        vm.expectEmit(false, false, false, true);
        emit AutoTriggerFired(
            EmergencyPause.TriggerReason.ORACLE_UNHEALTHY,
            EmergencyPause.PauseLevel.RESTRICTED,
            "Oracle down"
        );

        vm.prank(monitor);
        pause.triggerOracleUnhealthy("Oracle down");
    }

    function test_triggerOracleUnhealthy_noopWhenAlreadyRestricted() public {
        // Manually set to RESTRICTED first
        vm.prank(guardian);
        pause.setRestricted("Already restricted");

        uint256 historyBefore = pause.getLevelHistoryLength();

        // Oracle trigger should not add another level change
        vm.prank(monitor);
        pause.triggerOracleUnhealthy("Oracle stale again");

        assertEq(pause.getLevelHistoryLength(), historyBefore);
    }

    function test_triggerOracleUnhealthy_noopWhenAtEmergency() public {
        vm.prank(guardian);
        pause.setEmergency("Already emergency");

        uint256 historyBefore = pause.getLevelHistoryLength();

        vm.prank(monitor);
        pause.triggerOracleUnhealthy("Oracle stale");

        // No additional change
        assertEq(pause.getLevelHistoryLength(), historyBefore);
        assertEq(uint256(pause.currentLevel()), uint256(EmergencyPause.PauseLevel.EMERGENCY));
    }

    function test_triggerOracleUnhealthy_revertsForNonMonitor() public {
        vm.prank(attacker);
        vm.expectRevert();
        pause.triggerOracleUnhealthy("Unauthorized trigger");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // AUTO-TRIGGER: ORACLE STALE
    // ═══════════════════════════════════════════════════════════════════════════

    function test_triggerOracleStale_setsRestricted() public {
        vm.prank(monitor);
        pause.triggerOracleStale(3601); // > 1 hour threshold

        assertEq(uint256(pause.currentLevel()), uint256(EmergencyPause.PauseLevel.RESTRICTED));
    }

    function test_triggerOracleStale_noopBelowThreshold() public {
        vm.prank(monitor);
        pause.triggerOracleStale(3599); // < 1 hour threshold

        assertEq(uint256(pause.currentLevel()), uint256(EmergencyPause.PauseLevel.NORMAL));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // AUTO-TRIGGER: RESERVE MISMATCH
    // ═══════════════════════════════════════════════════════════════════════════

    function test_triggerReserveMismatch_setsEmergency() public {
        vm.prank(monitor);
        pause.triggerReserveMismatch(900_000, 1_000_000); // reserves < supply

        assertEq(uint256(pause.currentLevel()), uint256(EmergencyPause.PauseLevel.EMERGENCY));
        assertEq(uint256(pause.currentReason()), uint256(EmergencyPause.TriggerReason.RESERVE_MISMATCH));
    }

    function test_triggerReserveMismatch_noopWhenReservesAdequate() public {
        vm.prank(monitor);
        pause.triggerReserveMismatch(1_000_000, 1_000_000); // reserves == supply

        assertEq(uint256(pause.currentLevel()), uint256(EmergencyPause.PauseLevel.NORMAL));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // AUTO-TRIGGER: INVARIANT BREACH
    // ═══════════════════════════════════════════════════════════════════════════

    function test_triggerInvariantBreach_setsShutdown() public {
        vm.prank(monitor);
        pause.triggerInvariantBreach("INV-SM-1", "totalSupply exceeds backing");

        assertEq(uint256(pause.currentLevel()), uint256(EmergencyPause.PauseLevel.SHUTDOWN));
        assertEq(uint256(pause.currentReason()), uint256(EmergencyPause.TriggerReason.INVARIANT_BREACH));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // AUTO-TRIGGER: PRICE DEVIATION
    // ═══════════════════════════════════════════════════════════════════════════

    function test_triggerPriceDeviation_setsElevated() public {
        vm.prank(monitor);
        pause.triggerPriceDeviation(600); // 6% > 5% threshold

        assertEq(uint256(pause.currentLevel()), uint256(EmergencyPause.PauseLevel.ELEVATED));
    }

    function test_triggerPriceDeviation_noopBelowThreshold() public {
        vm.prank(monitor);
        pause.triggerPriceDeviation(400); // 4% < 5% threshold

        assertEq(uint256(pause.currentLevel()), uint256(EmergencyPause.PauseLevel.NORMAL));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // RECOVERY: RETURN TO NORMAL FROM ELEVATED
    // ═══════════════════════════════════════════════════════════════════════════

    function test_returnToNormalFromElevated_byGuardian() public {
        vm.prank(guardian);
        pause.setElevated("Temporary alert");

        vm.prank(guardian);
        pause.returnToNormalFromElevated();

        assertEq(uint256(pause.currentLevel()), uint256(EmergencyPause.PauseLevel.NORMAL));
    }

    function test_returnToNormalFromElevated_revertsWhenNotElevated() public {
        // At NORMAL level
        vm.prank(guardian);
        vm.expectRevert(EmergencyPause.InvalidLevelTransition.selector);
        pause.returnToNormalFromElevated();
    }

    function test_returnToNormalFromElevated_revertsWhenRestricted() public {
        vm.prank(guardian);
        pause.setRestricted("Too high for direct return");

        vm.prank(guardian);
        vm.expectRevert(EmergencyPause.InvalidLevelTransition.selector);
        pause.returnToNormalFromElevated();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // RECOVERY TIMELOCK TESTS (Level 2+)
    // ═══════════════════════════════════════════════════════════════════════════

    function test_requestRecovery_fromRestrictedRequiresTimelock() public {
        vm.prank(guardian);
        pause.setRestricted("Oracle issue");

        vm.prank(governor);
        pause.requestRecovery(EmergencyPause.PauseLevel.NORMAL);

        (EmergencyPause.PauseLevel targetLevel, uint256 executeAfter, bool pending,) = pause.pendingRecovery();
        assertTrue(pending);
        assertEq(uint256(targetLevel), uint256(EmergencyPause.PauseLevel.NORMAL));
        assertEq(executeAfter, block.timestamp + pause.RECOVERY_TIMELOCK());
    }

    function test_executeRecovery_afterTimelock() public {
        vm.prank(guardian);
        pause.setRestricted("Oracle issue");

        vm.prank(governor);
        pause.requestRecovery(EmergencyPause.PauseLevel.NORMAL);

        // Warp past timelock (24 hours)
        vm.warp(block.timestamp + pause.RECOVERY_TIMELOCK() + 1);

        vm.prank(governor);
        pause.executeRecovery();

        assertEq(uint256(pause.currentLevel()), uint256(EmergencyPause.PauseLevel.NORMAL));
    }

    function test_executeRecovery_revertsBeforeTimelock() public {
        vm.prank(guardian);
        pause.setRestricted("Oracle issue");

        vm.prank(governor);
        pause.requestRecovery(EmergencyPause.PauseLevel.NORMAL);

        // Try immediately
        vm.prank(governor);
        vm.expectRevert(EmergencyPause.RecoveryTimelockNotReady.selector);
        pause.executeRecovery();
    }

    function test_executeRecovery_revertsWhenNoPending() public {
        vm.prank(governor);
        vm.expectRevert(EmergencyPause.NoPendingRecovery.selector);
        pause.executeRecovery();
    }

    function test_requestRecovery_revertsWhenAlreadyPending() public {
        vm.prank(guardian);
        pause.setRestricted("Oracle issue");

        vm.startPrank(governor);
        pause.requestRecovery(EmergencyPause.PauseLevel.NORMAL);

        vm.expectRevert(EmergencyPause.RecoveryAlreadyPending.selector);
        pause.requestRecovery(EmergencyPause.PauseLevel.NORMAL);
        vm.stopPrank();
    }

    function test_requestRecovery_revertsWhenTargetNotLower() public {
        vm.prank(guardian);
        pause.setRestricted("Oracle issue");

        vm.prank(governor);
        vm.expectRevert(EmergencyPause.InvalidLevelTransition.selector);
        pause.requestRecovery(EmergencyPause.PauseLevel.EMERGENCY);
    }

    function test_cancelRecovery_byGovernor() public {
        vm.prank(guardian);
        pause.setRestricted("Oracle issue");

        vm.prank(governor);
        pause.requestRecovery(EmergencyPause.PauseLevel.NORMAL);

        vm.prank(governor);
        pause.cancelRecovery();

        (,,bool pending,) = pause.pendingRecovery();
        assertFalse(pending);
    }

    function test_cancelRecovery_revertsWhenNoPending() public {
        vm.prank(governor);
        vm.expectRevert(EmergencyPause.NoPendingRecovery.selector);
        pause.cancelRecovery();
    }

    function test_requestRecovery_fromEmergencyRequiresTimelock() public {
        vm.prank(guardian);
        pause.setEmergency("Critical event");

        vm.prank(governor);
        pause.requestRecovery(EmergencyPause.PauseLevel.NORMAL);

        (, uint256 executeAfter, bool pending,) = pause.pendingRecovery();
        assertTrue(pending);
        assertEq(executeAfter, block.timestamp + pause.RECOVERY_TIMELOCK());
    }

    function test_requestRecovery_fromShutdownRequiresTimelock() public {
        vm.prank(guardian);
        pause.setShutdown("Full shutdown");

        vm.prank(governor);
        pause.requestRecovery(EmergencyPause.PauseLevel.NORMAL);

        (, uint256 executeAfter, bool pending,) = pause.pendingRecovery();
        assertTrue(pending);
        assertEq(executeAfter, block.timestamp + pause.RECOVERY_TIMELOCK());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // LEVEL 2 BLOCKS MINTING (VIEW FUNCTION TESTS)
    // ═══════════════════════════════════════════════════════════════════════════

    function test_isMintingAllowed_trueAtNormal() public view {
        assertTrue(pause.isMintingAllowed());
    }

    function test_isMintingAllowed_trueAtElevated() public {
        vm.prank(guardian);
        pause.setElevated("Elevated monitoring");

        assertTrue(pause.isMintingAllowed());
    }

    function test_isMintingAllowed_falseAtRestricted() public {
        vm.prank(guardian);
        pause.setRestricted("Minting should be blocked");

        assertFalse(pause.isMintingAllowed());
    }

    function test_isMintingAllowed_falseAtEmergency() public {
        vm.prank(guardian);
        pause.setEmergency("Emergency");

        assertFalse(pause.isMintingAllowed());
    }

    function test_isMintingAllowed_falseAtShutdown() public {
        vm.prank(guardian);
        pause.setShutdown("Shutdown");

        assertFalse(pause.isMintingAllowed());
    }

    function test_isBurningAllowed_trueUpToRestricted() public {
        assertTrue(pause.isBurningAllowed());

        vm.prank(guardian);
        pause.setElevated("Elevated");
        assertTrue(pause.isBurningAllowed());

        // Reset to check RESTRICTED
        vm.prank(admin);
        pause = new EmergencyPause(admin);
        vm.prank(admin);
        pause.grantRole(pause.GUARDIAN_ROLE(), guardian);

        vm.prank(guardian);
        pause.setRestricted("Restricted");
        assertTrue(pause.isBurningAllowed());
    }

    function test_isBurningAllowed_falseAtEmergency() public {
        vm.prank(guardian);
        pause.setEmergency("Emergency");

        assertFalse(pause.isBurningAllowed());
    }

    function test_isTransferAllowed_falseAtEmergency() public {
        vm.prank(guardian);
        pause.setEmergency("Emergency");

        assertFalse(pause.isTransferAllowed());
    }

    function test_isFullyPaused_trueAtEmergencyAndShutdown() public {
        vm.prank(guardian);
        pause.setEmergency("Emergency");
        assertTrue(pause.isFullyPaused());
    }

    function test_isFullyPaused_falseAtRestricted() public {
        vm.prank(guardian);
        pause.setRestricted("Restricted");
        assertFalse(pause.isFullyPaused());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // EVENT EMISSION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_escalation_emitsLevelChangedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit LevelChanged(
            EmergencyPause.PauseLevel.NORMAL,
            EmergencyPause.PauseLevel.RESTRICTED,
            EmergencyPause.TriggerReason.MANUAL,
            guardian,
            "Oracle down"
        );

        vm.prank(guardian);
        pause.setRestricted("Oracle down");
    }

    function test_recovery_emitsRecoveryRequestedEvent() public {
        vm.prank(guardian);
        pause.setRestricted("Issue");

        vm.expectEmit(false, false, false, true);
        emit RecoveryRequested(
            EmergencyPause.PauseLevel.NORMAL,
            block.timestamp + pause.RECOVERY_TIMELOCK(),
            governor
        );

        vm.prank(governor);
        pause.requestRecovery(EmergencyPause.PauseLevel.NORMAL);
    }

    function test_recovery_emitsRecoveryExecutedEvent() public {
        vm.prank(guardian);
        pause.setRestricted("Issue");

        vm.prank(governor);
        pause.requestRecovery(EmergencyPause.PauseLevel.NORMAL);

        vm.warp(block.timestamp + pause.RECOVERY_TIMELOCK() + 1);

        vm.expectEmit(false, false, false, true);
        emit RecoveryExecuted(EmergencyPause.PauseLevel.NORMAL, governor);

        vm.prank(governor);
        pause.executeRecovery();
    }

    function test_cancelRecovery_emitsEvent() public {
        vm.prank(guardian);
        pause.setRestricted("Issue");

        vm.prank(governor);
        pause.requestRecovery(EmergencyPause.PauseLevel.NORMAL);

        vm.expectEmit(false, false, false, true);
        emit RecoveryCancelled(governor);

        vm.prank(governor);
        pause.cancelRecovery();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONTRACT REGISTRATION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_registerContract_byGovernor() public {
        address contractAddr = address(0xDEAD);

        vm.prank(governor);
        pause.registerContract(contractAddr);

        assertTrue(pause.registeredContracts(contractAddr));
    }

    function test_registerContract_revertsOnDuplicate() public {
        address contractAddr = address(0xDEAD);

        vm.startPrank(governor);
        pause.registerContract(contractAddr);

        vm.expectRevert(EmergencyPause.ContractAlreadyRegistered.selector);
        pause.registerContract(contractAddr);
        vm.stopPrank();
    }

    function test_registerContract_revertsOnZeroAddress() public {
        vm.prank(governor);
        vm.expectRevert(EmergencyPause.ZeroAddress.selector);
        pause.registerContract(address(0));
    }

    function test_unregisterContract_byGovernor() public {
        address contractAddr = address(0xDEAD);

        vm.startPrank(governor);
        pause.registerContract(contractAddr);
        pause.unregisterContract(contractAddr);
        vm.stopPrank();

        assertFalse(pause.registeredContracts(contractAddr));
    }

    function test_unregisterContract_revertsForUnknownContract() public {
        vm.prank(governor);
        vm.expectRevert(EmergencyPause.ContractNotRegistered.selector);
        pause.unregisterContract(address(0xDEAD));
    }

    function test_getRegisteredContracts_returnsAll() public {
        vm.startPrank(governor);
        pause.registerContract(address(0xA));
        pause.registerContract(address(0xB));
        pause.registerContract(address(0xC));
        vm.stopPrank();

        address[] memory contracts = pause.getRegisteredContracts();
        assertEq(contracts.length, 3);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // THRESHOLD CONFIGURATION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_setOracleStalenessThreshold_byGovernor() public {
        vm.prank(governor);
        pause.setOracleStalenessThreshold(2 hours);

        assertEq(pause.oracleStalenessThreshold(), 2 hours);
    }

    function test_setPriceDeviationThreshold_byGovernor() public {
        vm.prank(governor);
        pause.setPriceDeviationThreshold(1000); // 10%

        assertEq(pause.priceDeviationThreshold(), 1000);
    }

    function test_setThresholds_revertsForNonGovernor() public {
        vm.prank(attacker);
        vm.expectRevert();
        pause.setOracleStalenessThreshold(2 hours);

        vm.prank(attacker);
        vm.expectRevert();
        pause.setPriceDeviationThreshold(1000);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // LEVEL HISTORY TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_levelHistory_recordsChanges() public {
        vm.startPrank(guardian);
        pause.setElevated("First");
        pause.escalateLevel(
            EmergencyPause.PauseLevel.RESTRICTED,
            EmergencyPause.TriggerReason.MANUAL,
            "Second"
        );
        pause.escalateLevel(
            EmergencyPause.PauseLevel.EMERGENCY,
            EmergencyPause.TriggerReason.EXPLOIT_DETECTED,
            "Third"
        );
        vm.stopPrank();

        assertEq(pause.getLevelHistoryLength(), 3);

        EmergencyPause.LevelChange memory firstChange = pause.getLevelChange(0);
        assertEq(uint256(firstChange.fromLevel), uint256(EmergencyPause.PauseLevel.NORMAL));
        assertEq(uint256(firstChange.toLevel), uint256(EmergencyPause.PauseLevel.ELEVATED));

        EmergencyPause.LevelChange memory thirdChange = pause.getLevelChange(2);
        assertEq(uint256(thirdChange.fromLevel), uint256(EmergencyPause.PauseLevel.RESTRICTED));
        assertEq(uint256(thirdChange.toLevel), uint256(EmergencyPause.PauseLevel.EMERGENCY));
        assertEq(uint256(thirdChange.reason), uint256(EmergencyPause.TriggerReason.EXPLOIT_DETECTED));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // GET STATUS VIEW TEST
    // ═══════════════════════════════════════════════════════════════════════════

    function test_getStatus_returnsCorrectValues() public {
        vm.prank(guardian);
        pause.setRestricted("Oracle down");

        (
            EmergencyPause.PauseLevel level,
            EmergencyPause.TriggerReason reason,
            string memory details,
            uint256 setAt,
            bool mintingAllowed,
            bool burningAllowed,
            bool transfersAllowed
        ) = pause.getStatus();

        assertEq(uint256(level), uint256(EmergencyPause.PauseLevel.RESTRICTED));
        assertEq(uint256(reason), uint256(EmergencyPause.TriggerReason.MANUAL));
        assertEq(details, "Oracle down");
        assertEq(setAt, block.timestamp);
        assertFalse(mintingAllowed);  // RESTRICTED blocks minting
        assertTrue(burningAllowed);   // RESTRICTED allows burning
        assertTrue(transfersAllowed); // RESTRICTED allows transfers
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUZZ TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function testFuzz_triggerOracleStale_thresholdBehavior(uint256 staleness) public {
        staleness = bound(staleness, 0, 10 hours);

        vm.prank(monitor);
        pause.triggerOracleStale(staleness);

        if (staleness >= pause.oracleStalenessThreshold()) {
            assertEq(uint256(pause.currentLevel()), uint256(EmergencyPause.PauseLevel.RESTRICTED));
        } else {
            assertEq(uint256(pause.currentLevel()), uint256(EmergencyPause.PauseLevel.NORMAL));
        }
    }

    function testFuzz_triggerPriceDeviation_thresholdBehavior(uint256 deviation) public {
        deviation = bound(deviation, 0, 5000);

        vm.prank(monitor);
        pause.triggerPriceDeviation(deviation);

        if (deviation >= pause.priceDeviationThreshold()) {
            assertEq(uint256(pause.currentLevel()), uint256(EmergencyPause.PauseLevel.ELEVATED));
        } else {
            assertEq(uint256(pause.currentLevel()), uint256(EmergencyPause.PauseLevel.NORMAL));
        }
    }
}
