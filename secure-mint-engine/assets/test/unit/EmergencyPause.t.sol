// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/EmergencyPause.sol";
import "../../contracts/BackedToken.sol";
import "../../contracts/SecureMintPolicy.sol";
import "../mocks/MockOracle.sol";

/**
 * @title EmergencyPauseTest
 * @notice Unit tests for the EmergencyPause 4-level graduated circuit breaker.
 */
contract EmergencyPauseTest is Test {
    // -------------------------------------------------------------------
    //  State
    // -------------------------------------------------------------------

    EmergencyPause public ep;
    BackedToken public token;
    SecureMintPolicy public policy;
    MockOracle public oracle;

    address public admin = makeAddr("admin");
    address public guardian = makeAddr("guardian");
    address public dao = makeAddr("dao");
    address public user = makeAddr("user");

    uint256 public constant FREEZE_TIMELOCK = 3 days;
    uint256 public constant COOLDOWN = 1 hours;

    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant DAO_ROLE = keccak256("DAO_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // -------------------------------------------------------------------
    //  Setup
    // -------------------------------------------------------------------

    function setUp() public {
        // Deploy token and oracle for integration hook testing
        token = new BackedToken("USD Backed Token", "USDX", 18, admin);
        oracle = new MockOracle();

        // Deploy policy
        policy = new SecureMintPolicy(
            address(token),
            address(oracle),
            10_000_000e18,
            1_000_000e18,
            24 hours,
            3600,
            500,
            2 days,
            admin
        );

        // Deploy EmergencyPause with references to token and policy
        ep = new EmergencyPause(
            admin,
            FREEZE_TIMELOCK,
            COOLDOWN,
            address(token),
            address(policy)
        );

        // Grant roles on EmergencyPause
        vm.startPrank(admin);
        ep.grantRole(GUARDIAN_ROLE, guardian);
        ep.grantRole(DAO_ROLE, dao);

        // Grant PAUSER_ROLE on BackedToken to EmergencyPause so hooks work
        token.grantRole(PAUSER_ROLE, address(ep));

        // Register EmergencyPause on SecureMintPolicy so hooks work
        policy.setEmergencyPause(address(ep));
        vm.stopPrank();
    }

    // -------------------------------------------------------------------
    //  Escalation Tests
    // -------------------------------------------------------------------

    function test_EscalateLevel_L0ToL1() public {
        assertEq(uint8(ep.currentLevel()), 0);

        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_1_MINT_PAUSED, "Oracle anomaly");

        assertEq(uint8(ep.currentLevel()), 1);
    }

    function test_EscalateLevel_L1ToL2() public {
        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_1_MINT_PAUSED, "Step 1");

        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_2_RESTRICTED, "Step 2");

        assertEq(uint8(ep.currentLevel()), 2);
    }

    function test_EscalateLevel_L2ToL3() public {
        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_2_RESTRICTED, "Step 1");

        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_3_FULL_FREEZE, "Full freeze");

        assertEq(uint8(ep.currentLevel()), 3);
        assertTrue(ep.isFullFreeze());
    }

    function test_EscalateSkipLevels_L0ToL3() public {
        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_3_FULL_FREEZE, "Critical incident");

        assertEq(uint8(ep.currentLevel()), 3);
        assertTrue(ep.fullFreezeAvailableAt() > 0);
    }

    function test_RevertEscalateToSameOrLower() public {
        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_2_RESTRICTED, "Initial");

        // Same level
        vm.prank(guardian);
        vm.expectRevert(
            abi.encodeWithSelector(
                EmergencyPause.CannotEscalateToSameOrLower.selector,
                EmergencyPause.PauseLevel.LEVEL_2_RESTRICTED,
                EmergencyPause.PauseLevel.LEVEL_2_RESTRICTED
            )
        );
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_2_RESTRICTED, "Same");

        // Lower level
        vm.prank(guardian);
        vm.expectRevert(
            abi.encodeWithSelector(
                EmergencyPause.CannotEscalateToSameOrLower.selector,
                EmergencyPause.PauseLevel.LEVEL_2_RESTRICTED,
                EmergencyPause.PauseLevel.LEVEL_1_MINT_PAUSED
            )
        );
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_1_MINT_PAUSED, "Lower");
    }

    function test_EscalateRevertsWithoutGuardianRole() public {
        vm.prank(user);
        vm.expectRevert();
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_1_MINT_PAUSED, "Unauthorized");
    }

    // -------------------------------------------------------------------
    //  De-escalation Tests
    // -------------------------------------------------------------------

    function test_DeescalateLevel_L2ToL1() public {
        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_2_RESTRICTED, "Escalate");

        vm.prank(admin);
        ep.deescalate(EmergencyPause.PauseLevel.LEVEL_1_MINT_PAUSED, "Partial recovery");

        assertEq(uint8(ep.currentLevel()), 1);
    }

    function test_DeescalateLevel_L1ToL0() public {
        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_1_MINT_PAUSED, "Escalate");

        vm.prank(admin);
        ep.deescalate(EmergencyPause.PauseLevel.LEVEL_0_NORMAL, "All clear");

        assertEq(uint8(ep.currentLevel()), 0);
    }

    function test_DeescalateRevertsToSameOrHigher() public {
        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_2_RESTRICTED, "Escalate");

        // Same level
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                EmergencyPause.CannotEscalateToSameOrLower.selector,
                EmergencyPause.PauseLevel.LEVEL_2_RESTRICTED,
                EmergencyPause.PauseLevel.LEVEL_2_RESTRICTED
            )
        );
        ep.deescalate(EmergencyPause.PauseLevel.LEVEL_2_RESTRICTED, "Same");

        // Higher level
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                EmergencyPause.CannotEscalateToSameOrLower.selector,
                EmergencyPause.PauseLevel.LEVEL_2_RESTRICTED,
                EmergencyPause.PauseLevel.LEVEL_3_FULL_FREEZE
            )
        );
        ep.deescalate(EmergencyPause.PauseLevel.LEVEL_3_FULL_FREEZE, "Higher");
    }

    function test_DeescalateRevertsWithoutAdminRole() public {
        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_1_MINT_PAUSED, "Escalate");

        vm.prank(user);
        vm.expectRevert();
        ep.deescalate(EmergencyPause.PauseLevel.LEVEL_0_NORMAL, "Unauthorized");
    }

    // -------------------------------------------------------------------
    //  Full Freeze Timelock Tests
    // -------------------------------------------------------------------

    function test_FullFreezeTimelock() public {
        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_3_FULL_FREEZE, "Full freeze");

        uint256 expectedAvailableAt = block.timestamp + FREEZE_TIMELOCK;
        assertEq(ep.fullFreezeAvailableAt(), expectedAvailableAt);

        // Try to deescalate before timelock expires
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                EmergencyPause.FullFreezeTimelockActive.selector,
                expectedAvailableAt
            )
        );
        ep.deescalate(EmergencyPause.PauseLevel.LEVEL_2_RESTRICTED, "Too early");

        // After timelock expires, deescalation should succeed
        vm.warp(expectedAvailableAt);

        vm.prank(admin);
        ep.deescalate(EmergencyPause.PauseLevel.LEVEL_2_RESTRICTED, "Timelock elapsed");

        assertEq(uint8(ep.currentLevel()), 2);
    }

    function test_FullFreezeTimelockPartialWait() public {
        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_3_FULL_FREEZE, "Freeze");

        // Warp to just before the timelock expires
        vm.warp(block.timestamp + FREEZE_TIMELOCK - 1);

        vm.prank(admin);
        vm.expectRevert();
        ep.deescalate(EmergencyPause.PauseLevel.LEVEL_0_NORMAL, "Still locked");
    }

    // -------------------------------------------------------------------
    //  Cooldown Tests
    // -------------------------------------------------------------------

    function test_CooldownAfterDeescalation() public {
        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_2_RESTRICTED, "Escalate");

        // First deescalation works
        vm.prank(admin);
        ep.deescalate(EmergencyPause.PauseLevel.LEVEL_1_MINT_PAUSED, "Step down");
        assertEq(uint8(ep.currentLevel()), 1);

        // Immediate second deescalation should revert due to cooldown
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                EmergencyPause.CooldownActive.selector,
                block.timestamp + COOLDOWN
            )
        );
        ep.deescalate(EmergencyPause.PauseLevel.LEVEL_0_NORMAL, "Too fast");

        // After cooldown elapses, should work
        vm.warp(block.timestamp + COOLDOWN);

        vm.prank(admin);
        ep.deescalate(EmergencyPause.PauseLevel.LEVEL_0_NORMAL, "Cooldown elapsed");
        assertEq(uint8(ep.currentLevel()), 0);
    }

    // -------------------------------------------------------------------
    //  DAO Override Tests
    // -------------------------------------------------------------------

    function test_DaoOverride() public {
        // Escalate to full freeze
        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_3_FULL_FREEZE, "Full freeze");

        // DAO can immediately override, bypassing timelock and cooldown
        vm.prank(dao);
        ep.daoOverride(EmergencyPause.PauseLevel.LEVEL_0_NORMAL);

        assertEq(uint8(ep.currentLevel()), 0);
        // Cooldown and timelock should be cleared
        assertEq(ep.cooldownEndsAt(), 0);
        assertEq(ep.fullFreezeAvailableAt(), 0);
    }

    function test_DaoOverrideToAnyLevel() public {
        // DAO can set to any level, even escalating
        vm.prank(dao);
        ep.daoOverride(EmergencyPause.PauseLevel.LEVEL_2_RESTRICTED);
        assertEq(uint8(ep.currentLevel()), 2);

        // DAO can then go back down
        vm.prank(dao);
        ep.daoOverride(EmergencyPause.PauseLevel.LEVEL_0_NORMAL);
        assertEq(uint8(ep.currentLevel()), 0);
    }

    function test_DaoOverrideRevertsWithoutDaoRole() public {
        vm.prank(user);
        vm.expectRevert();
        ep.daoOverride(EmergencyPause.PauseLevel.LEVEL_0_NORMAL);
    }

    function test_DaoOverrideBypassesCooldown() public {
        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_2_RESTRICTED, "Escalate");

        // Deescalate to trigger cooldown
        vm.prank(admin);
        ep.deescalate(EmergencyPause.PauseLevel.LEVEL_1_MINT_PAUSED, "Step down");

        // Admin would be blocked by cooldown, but DAO is not
        vm.prank(dao);
        ep.daoOverride(EmergencyPause.PauseLevel.LEVEL_0_NORMAL);
        assertEq(uint8(ep.currentLevel()), 0);
    }

    // -------------------------------------------------------------------
    //  Integration Hook Tests
    // -------------------------------------------------------------------

    function test_IntegrationHooksCalled_BackedTokenPaused() public {
        // When escalating to L2, BackedToken should become paused
        assertFalse(token.paused());

        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_2_RESTRICTED, "Restrict transfers");

        assertTrue(token.paused());
    }

    function test_IntegrationHooksCalled_BackedTokenUnpaused() public {
        // Escalate to L2 (pauses token)
        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_2_RESTRICTED, "Pause");
        assertTrue(token.paused());

        // Deescalate to L0 (unpauses token)
        vm.prank(admin);
        ep.deescalate(EmergencyPause.PauseLevel.LEVEL_0_NORMAL, "Resume");
        assertFalse(token.paused());
    }

    function test_IntegrationHooksCalled_PolicyPaused() public {
        // When escalating to L1, SecureMintPolicy should become paused
        assertFalse(policy.paused());

        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_1_MINT_PAUSED, "Pause minting");

        assertTrue(policy.paused());
    }

    function test_IntegrationHooksCalled_PolicyUnpaused() public {
        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_1_MINT_PAUSED, "Pause minting");
        assertTrue(policy.paused());

        vm.prank(admin);
        ep.deescalate(EmergencyPause.PauseLevel.LEVEL_0_NORMAL, "Resume");
        assertFalse(policy.paused());
    }

    function test_IntegrationHooks_L3FreezesBoth() public {
        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_3_FULL_FREEZE, "Full freeze");

        assertTrue(token.paused());
        assertTrue(policy.paused());
    }

    function test_IntegrationHooks_DaoOverrideUnfreezes() public {
        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_3_FULL_FREEZE, "Full freeze");

        assertTrue(token.paused());
        assertTrue(policy.paused());

        vm.prank(dao);
        ep.daoOverride(EmergencyPause.PauseLevel.LEVEL_0_NORMAL);

        assertFalse(token.paused());
        assertFalse(policy.paused());
    }

    // -------------------------------------------------------------------
    //  View Helper Tests
    // -------------------------------------------------------------------

    function test_IsMintPaused() public {
        assertFalse(ep.isMintPaused());

        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_1_MINT_PAUSED, "Pause mint");
        assertTrue(ep.isMintPaused());
    }

    function test_IsTransferPaused() public {
        assertFalse(ep.isTransferPaused());

        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_2_RESTRICTED, "Restrict");
        assertTrue(ep.isTransferPaused());
    }

    function test_IsFullFreeze() public {
        assertFalse(ep.isFullFreeze());

        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_3_FULL_FREEZE, "Freeze");
        assertTrue(ep.isFullFreeze());
    }

    function test_L1DoesNotPauseTransfers() public {
        vm.prank(guardian);
        ep.escalate(EmergencyPause.PauseLevel.LEVEL_1_MINT_PAUSED, "Mint only");

        assertTrue(ep.isMintPaused());
        assertFalse(ep.isTransferPaused());
        assertFalse(ep.isFullFreeze());
    }

    // -------------------------------------------------------------------
    //  Constructor Tests
    // -------------------------------------------------------------------

    function test_ConstructorRevertsZeroAdmin() public {
        vm.expectRevert("EmergencyPause: zero admin");
        new EmergencyPause(
            address(0),
            FREEZE_TIMELOCK,
            COOLDOWN,
            address(token),
            address(policy)
        );
    }

    function test_ConstructorAcceptsZeroIntegrationAddresses() public {
        // Zero addresses for token/policy are allowed (hooks simply skip)
        EmergencyPause ep2 = new EmergencyPause(
            admin,
            FREEZE_TIMELOCK,
            COOLDOWN,
            address(0),
            address(0)
        );

        assertEq(uint8(ep2.currentLevel()), 0);
    }
}
