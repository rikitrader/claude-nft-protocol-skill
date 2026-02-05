// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/OracleRouter.sol";
import "../mocks/MockOracle.sol";

/**
 * @title RevertingOracle
 * @notice A mock oracle whose isHealthy() always reverts, simulating a broken feed.
 */
contract RevertingOracle is IBackingOracle {
    function MAX_STALENESS() external pure override returns (uint256) { return 3600; }
    function MAX_DEVIATION() external pure override returns (uint256) { return 500; }

    function getBackingAmount() external pure override returns (uint256) {
        revert("RevertingOracle: broken");
    }

    function isHealthy() external pure override returns (bool) {
        revert("RevertingOracle: broken");
    }

    function lastUpdate() external pure override returns (uint256) {
        revert("RevertingOracle: broken");
    }

    function deviation() external pure override returns (uint256) {
        revert("RevertingOracle: broken");
    }

    function sourceCount() external pure override returns (uint256) { return 1; }
    function confidence() external pure override returns (uint256) { return 0; }
}

/**
 * @title OracleRouterTest
 * @notice Unit tests for OracleRouter contract.
 */
contract OracleRouterTest is Test {
    // -------------------------------------------------------------------
    //  Local event declarations (Solidity <0.8.21 compat)
    // -------------------------------------------------------------------

    event FallbackAdded(address indexed oracle, uint256 index);
    event FallbackRemoved(address indexed oracle, uint256 index);
    event PrimaryOracleChanged(address indexed previousPrimary, address indexed newPrimary);
    event OracleFailover(address indexed failedOracle, address indexed fallbackOracle, uint256 timestamp);

    // -------------------------------------------------------------------
    //  State
    // -------------------------------------------------------------------

    OracleRouter public router;
    MockOracle public primaryOracle;
    MockOracle public fallbackOracleA;
    MockOracle public fallbackOracleB;

    address public admin = makeAddr("admin");
    address public nonAdmin = makeAddr("nonAdmin");

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // -------------------------------------------------------------------
    //  Setup
    // -------------------------------------------------------------------

    function setUp() public {
        primaryOracle = new MockOracle();
        fallbackOracleA = new MockOracle();
        fallbackOracleB = new MockOracle();

        router = new OracleRouter(address(primaryOracle), admin);
    }

    // ===================================================================
    //  Constructor Tests
    // ===================================================================

    function test_Constructor_SetsPrimaryOracle() public view {
        assertEq(address(router.primaryOracle()), address(primaryOracle));
    }

    function test_Constructor_GrantsRoles() public view {
        assertTrue(router.hasRole(router.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(router.hasRole(ADMIN_ROLE, admin));
    }

    function test_Constructor_MarksPrimaryAsSource() public view {
        assertTrue(router.isSource(address(primaryOracle)));
    }

    function test_Constructor_RevertsOnZeroPrimary() public {
        vm.expectRevert("OracleRouter: zero primary");
        new OracleRouter(address(0), admin);
    }

    function test_Constructor_RevertsOnZeroAdmin() public {
        vm.expectRevert("OracleRouter: zero admin");
        new OracleRouter(address(primaryOracle), address(0));
    }

    // ===================================================================
    //  addFallbackOracle Tests
    // ===================================================================

    function test_AddFallbackOracle_Success() public {
        vm.prank(admin);
        router.addFallbackOracle(address(fallbackOracleA));

        assertEq(router.fallbackCount(), 1);
        assertTrue(router.isSource(address(fallbackOracleA)));
    }

    function test_AddFallbackOracle_EmitsFallbackAdded() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit FallbackAdded(address(fallbackOracleA), 0);

        router.addFallbackOracle(address(fallbackOracleA));
    }

    function test_AddFallbackOracle_MultipleOracles() public {
        vm.startPrank(admin);
        router.addFallbackOracle(address(fallbackOracleA));
        router.addFallbackOracle(address(fallbackOracleB));
        vm.stopPrank();

        assertEq(router.fallbackCount(), 2);
    }

    function test_AddFallbackOracle_RevertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("OracleRouter: zero address");
        router.addFallbackOracle(address(0));
    }

    function test_AddFallbackOracle_RevertsOnDuplicate() public {
        vm.startPrank(admin);
        router.addFallbackOracle(address(fallbackOracleA));

        vm.expectRevert(
            abi.encodeWithSelector(
                OracleRouter.OracleAlreadyAdded.selector,
                address(fallbackOracleA)
            )
        );
        router.addFallbackOracle(address(fallbackOracleA));
        vm.stopPrank();
    }

    function test_AddFallbackOracle_RevertsIfPrimaryAlreadyAdded() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                OracleRouter.OracleAlreadyAdded.selector,
                address(primaryOracle)
            )
        );
        router.addFallbackOracle(address(primaryOracle));
    }

    function test_AddFallbackOracle_RevertsWithoutAdminRole() public {
        vm.prank(nonAdmin);
        vm.expectRevert();
        router.addFallbackOracle(address(fallbackOracleA));
    }

    // ===================================================================
    //  removeFallbackOracle Tests
    // ===================================================================

    function test_RemoveFallbackOracle_Success() public {
        vm.startPrank(admin);
        router.addFallbackOracle(address(fallbackOracleA));

        router.removeFallbackOracle(0);
        vm.stopPrank();

        assertEq(router.fallbackCount(), 0);
        assertFalse(router.isSource(address(fallbackOracleA)));
    }

    function test_RemoveFallbackOracle_EmitsFallbackRemoved() public {
        vm.startPrank(admin);
        router.addFallbackOracle(address(fallbackOracleA));

        vm.expectEmit(true, false, false, true);
        emit FallbackRemoved(address(fallbackOracleA), 0);

        router.removeFallbackOracle(0);
        vm.stopPrank();
    }

    function test_RemoveFallbackOracle_SwapAndPop() public {
        vm.startPrank(admin);
        router.addFallbackOracle(address(fallbackOracleA));
        router.addFallbackOracle(address(fallbackOracleB));

        // Remove index 0 — oracleB should be swapped into index 0
        router.removeFallbackOracle(0);
        vm.stopPrank();

        assertEq(router.fallbackCount(), 1);
        assertFalse(router.isSource(address(fallbackOracleA)));
        assertTrue(router.isSource(address(fallbackOracleB)));
    }

    function test_RemoveFallbackOracle_RevertsOnInvalidIndex() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                OracleRouter.InvalidIndex.selector,
                0,
                0
            )
        );
        router.removeFallbackOracle(0);
    }

    function test_RemoveFallbackOracle_RevertsWithoutAdminRole() public {
        vm.startPrank(admin);
        router.addFallbackOracle(address(fallbackOracleA));
        vm.stopPrank();

        vm.prank(nonAdmin);
        vm.expectRevert();
        router.removeFallbackOracle(0);
    }

    // ===================================================================
    //  setPrimaryOracle Tests
    // ===================================================================

    function test_SetPrimaryOracle_Success() public {
        MockOracle newPrimary = new MockOracle();

        vm.prank(admin);
        router.setPrimaryOracle(address(newPrimary));

        assertEq(address(router.primaryOracle()), address(newPrimary));
        assertTrue(router.isSource(address(newPrimary)));
        assertFalse(router.isSource(address(primaryOracle)));
    }

    function test_SetPrimaryOracle_EmitsPrimaryOracleChanged() public {
        MockOracle newPrimary = new MockOracle();

        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit PrimaryOracleChanged(
            address(primaryOracle),
            address(newPrimary)
        );

        router.setPrimaryOracle(address(newPrimary));
    }

    function test_SetPrimaryOracle_RevertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("OracleRouter: zero address");
        router.setPrimaryOracle(address(0));
    }

    function test_SetPrimaryOracle_RevertsOnDuplicateSource() public {
        vm.startPrank(admin);
        router.addFallbackOracle(address(fallbackOracleA));

        vm.expectRevert(
            abi.encodeWithSelector(
                OracleRouter.OracleAlreadyAdded.selector,
                address(fallbackOracleA)
            )
        );
        router.setPrimaryOracle(address(fallbackOracleA));
        vm.stopPrank();
    }

    function test_SetPrimaryOracle_RevertsWithoutAdminRole() public {
        vm.prank(nonAdmin);
        vm.expectRevert();
        router.setPrimaryOracle(address(fallbackOracleA));
    }

    // ===================================================================
    //  getBackingAmount Tests
    // ===================================================================

    function test_GetBackingAmount_ReturnsPrimaryWhenHealthy() public view {
        assertEq(router.getBackingAmount(), primaryOracle.getBackingAmount());
    }

    function test_GetBackingAmount_FallsBackWhenPrimaryUnhealthy() public {
        vm.prank(admin);
        router.addFallbackOracle(address(fallbackOracleA));

        // Make primary unhealthy
        primaryOracle.setHealthy(false);
        fallbackOracleA.setBackingAmount(999e18);

        assertEq(router.getBackingAmount(), 999e18);
    }

    function test_GetBackingAmount_RevertsWhenNoHealthyOracle() public {
        primaryOracle.setHealthy(false);

        vm.expectRevert(OracleRouter.NoHealthyOracle.selector);
        router.getBackingAmount();
    }

    function test_GetBackingAmount_SkipsUnhealthyFallback() public {
        vm.startPrank(admin);
        router.addFallbackOracle(address(fallbackOracleA));
        router.addFallbackOracle(address(fallbackOracleB));
        vm.stopPrank();

        // Primary unhealthy, fallbackA unhealthy, fallbackB healthy
        primaryOracle.setHealthy(false);
        fallbackOracleA.setHealthy(false);
        fallbackOracleB.setBackingAmount(777e18);

        assertEq(router.getBackingAmount(), 777e18);
    }

    // ===================================================================
    //  getBackingAmountWithFailover Tests
    // ===================================================================

    function test_GetBackingAmountWithFailover_ReturnsPrimaryWhenHealthy() public {
        uint256 amount = router.getBackingAmountWithFailover();
        assertEq(amount, primaryOracle.getBackingAmount());
    }

    function test_GetBackingAmountWithFailover_EmitsFailoverEvent() public {
        vm.prank(admin);
        router.addFallbackOracle(address(fallbackOracleA));

        primaryOracle.setHealthy(false);
        fallbackOracleA.setBackingAmount(888e18);

        vm.expectEmit(true, true, false, true);
        emit OracleFailover(
            address(primaryOracle),
            address(fallbackOracleA),
            block.timestamp
        );

        uint256 amount = router.getBackingAmountWithFailover();
        assertEq(amount, 888e18);
    }

    function test_GetBackingAmountWithFailover_RevertsWhenNoHealthy() public {
        primaryOracle.setHealthy(false);

        vm.expectRevert(OracleRouter.NoHealthyOracle.selector);
        router.getBackingAmountWithFailover();
    }

    // ===================================================================
    //  Failover with Reverting Oracle
    // ===================================================================

    function test_GetBackingAmount_HandlesPrimaryThatReverts() public {
        RevertingOracle broken = new RevertingOracle();
        MockOracle backup = new MockOracle();
        backup.setBackingAmount(555e18);

        OracleRouter routerWithBroken = new OracleRouter(address(broken), admin);

        vm.prank(admin);
        routerWithBroken.addFallbackOracle(address(backup));

        // Primary reverts on isHealthy(), so _isSourceHealthy returns false.
        // Falls back to the healthy backup.
        assertEq(routerWithBroken.getBackingAmount(), 555e18);
    }

    function test_GetBackingAmount_AllRevertingRevertsNoHealthy() public {
        RevertingOracle broken = new RevertingOracle();
        OracleRouter routerBroken = new OracleRouter(address(broken), admin);

        vm.expectRevert(OracleRouter.NoHealthyOracle.selector);
        routerBroken.getBackingAmount();
    }

    // ===================================================================
    //  isHealthy Tests
    // ===================================================================

    function test_IsHealthy_TrueWhenPrimaryHealthy() public view {
        assertTrue(router.isHealthy());
    }

    function test_IsHealthy_TrueWhenFallbackHealthy() public {
        vm.prank(admin);
        router.addFallbackOracle(address(fallbackOracleA));

        primaryOracle.setHealthy(false);

        assertTrue(router.isHealthy());
    }

    function test_IsHealthy_FalseWhenAllUnhealthy() public {
        vm.prank(admin);
        router.addFallbackOracle(address(fallbackOracleA));

        primaryOracle.setHealthy(false);
        fallbackOracleA.setHealthy(false);

        assertFalse(router.isHealthy());
    }

    function test_IsHealthy_FalseWhenPrimaryOnlyAndUnhealthy() public {
        primaryOracle.setHealthy(false);
        assertFalse(router.isHealthy());
    }

    // ===================================================================
    //  lastUpdate Tests
    // ===================================================================

    function test_LastUpdate_ReturnsPrimaryWhenOnlySource() public view {
        assertEq(router.lastUpdate(), primaryOracle.lastUpdate());
    }

    function test_LastUpdate_ReturnsMostRecent() public {
        vm.prank(admin);
        router.addFallbackOracle(address(fallbackOracleA));

        // Set fallbackA to have a newer timestamp
        fallbackOracleA.setLastUpdate(block.timestamp + 100);

        uint256 ts = router.lastUpdate();
        assertEq(ts, block.timestamp + 100);
    }

    function test_LastUpdate_ReturnsZeroWhenAllUnhealthy() public {
        primaryOracle.setHealthy(false);
        assertEq(router.lastUpdate(), 0);
    }

    // ===================================================================
    //  deviation Tests
    // ===================================================================

    function test_Deviation_ReturnsPrimaryDeviationWhenHealthy() public {
        primaryOracle.setDeviation(250);
        assertEq(router.deviation(), 250);
    }

    function test_Deviation_ReturnsFallbackDeviationWhenPrimaryUnhealthy() public {
        vm.prank(admin);
        router.addFallbackOracle(address(fallbackOracleA));

        primaryOracle.setHealthy(false);
        fallbackOracleA.setDeviation(300);

        assertEq(router.deviation(), 300);
    }

    function test_Deviation_ReturnsMaxWhenAllUnhealthy() public {
        primaryOracle.setHealthy(false);
        assertEq(router.deviation(), type(uint256).max);
    }

    // ===================================================================
    //  sourceCount Tests
    // ===================================================================

    function test_SourceCount_OnlyPrimary() public view {
        assertEq(router.sourceCount(), 1);
    }

    function test_SourceCount_WithFallbacks() public {
        vm.startPrank(admin);
        router.addFallbackOracle(address(fallbackOracleA));
        router.addFallbackOracle(address(fallbackOracleB));
        vm.stopPrank();

        assertEq(router.sourceCount(), 3);
    }

    // ===================================================================
    //  confidence Tests
    // ===================================================================

    function test_Confidence_SingleHealthySource() public view {
        // Single source delegates to primary's confidence (10_000 by default)
        assertEq(router.confidence(), 10_000);
    }

    function test_Confidence_ZeroWhenNoHealthySources() public {
        primaryOracle.setHealthy(false);
        assertEq(router.confidence(), 0);
    }

    function test_Confidence_AgreementBetweenSources() public {
        vm.prank(admin);
        router.addFallbackOracle(address(fallbackOracleA));

        // Both return same backing amount (1e24 by default) — full agreement
        assertEq(router.confidence(), 10_000);
    }

    function test_Confidence_DisagreementReducesScore() public {
        vm.prank(admin);
        router.addFallbackOracle(address(fallbackOracleA));

        // Primary: 1e24, FallbackA: very different value
        fallbackOracleA.setBackingAmount(5e23); // 50% different — way beyond 100 bps threshold

        // 1 out of 2 agree with reference => confidence = 1 * 10000 / 2 = 5000
        assertEq(router.confidence(), 5000);
    }

    // ===================================================================
    //  allSources Tests
    // ===================================================================

    function test_AllSources_OnlyPrimary() public view {
        address[] memory sources = router.allSources();
        assertEq(sources.length, 1);
        assertEq(sources[0], address(primaryOracle));
    }

    function test_AllSources_WithFallbacks() public {
        vm.startPrank(admin);
        router.addFallbackOracle(address(fallbackOracleA));
        router.addFallbackOracle(address(fallbackOracleB));
        vm.stopPrank();

        address[] memory sources = router.allSources();
        assertEq(sources.length, 3);
        assertEq(sources[0], address(primaryOracle));
        assertEq(sources[1], address(fallbackOracleA));
        assertEq(sources[2], address(fallbackOracleB));
    }

    // ===================================================================
    //  MAX_STALENESS / MAX_DEVIATION proxy Tests
    // ===================================================================

    function test_MaxStaleness_ProxiesToPrimary() public view {
        assertEq(router.MAX_STALENESS(), primaryOracle.MAX_STALENESS());
    }

    function test_MaxDeviation_ProxiesToPrimary() public view {
        assertEq(router.MAX_DEVIATION(), primaryOracle.MAX_DEVIATION());
    }

    function test_MaxStaleness_ReflectsPrimaryUpdate() public {
        primaryOracle.setMaxStaleness(7200);
        assertEq(router.MAX_STALENESS(), 7200);
    }
}
