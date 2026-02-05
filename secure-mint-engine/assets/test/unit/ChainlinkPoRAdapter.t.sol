// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/ChainlinkPoRAdapter.sol";

// ---------------------------------------------------------------------------
//  Mock Aggregator — mimics Chainlink AggregatorV3Interface
// ---------------------------------------------------------------------------

contract MockAggregatorV3 {
    uint8 private _decimals;
    int256 private _answer;
    uint256 private _updatedAt;
    uint80 private _roundId;

    constructor(uint8 dec, int256 initialAnswer, uint256 initialUpdatedAt) {
        _decimals = dec;
        _answer = initialAnswer;
        _updatedAt = initialUpdatedAt;
        _roundId = 1;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, _answer, _updatedAt, _updatedAt, _roundId);
    }

    // --- Test helpers ---

    function setAnswer(int256 newAnswer) external {
        _answer = newAnswer;
    }

    function setUpdatedAt(uint256 newUpdatedAt) external {
        _updatedAt = newUpdatedAt;
    }

    function setRoundId(uint80 newRoundId) external {
        _roundId = newRoundId;
    }
}

// ---------------------------------------------------------------------------
//  Test Suite
// ---------------------------------------------------------------------------

/**
 * @title ChainlinkPoRAdapterTest
 * @notice Unit tests for ChainlinkPoRAdapter contract.
 */
contract ChainlinkPoRAdapterTest is Test {
    // -------------------------------------------------------------------
    //  Events (declared locally for Solidity 0.8.20 compat)
    // -------------------------------------------------------------------

    event BackingUpdated(
        uint256 indexed newBacking,
        uint256 timestamp,
        address indexed reporter
    );

    // -------------------------------------------------------------------
    //  State
    // -------------------------------------------------------------------

    ChainlinkPoRAdapter public adapter;
    MockAggregatorV3 public aggregator;

    address public admin = makeAddr("admin");
    address public nonAdmin = makeAddr("nonAdmin");

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 public constant DEFAULT_STALENESS = 3600; // 1 hour
    uint256 public constant DEFAULT_DEVIATION = 500;  // 5%
    uint8 public constant FEED_DECIMALS = 8;
    int256 public constant INITIAL_ANSWER = 1_000_000e8; // 1M tokens in 8 decimals

    // -------------------------------------------------------------------
    //  Setup
    // -------------------------------------------------------------------

    function setUp() public {
        // Warp to a sensible timestamp so updatedAt arithmetic works.
        vm.warp(1_700_000_000);

        aggregator = new MockAggregatorV3(
            FEED_DECIMALS,
            INITIAL_ANSWER,
            block.timestamp
        );

        adapter = new ChainlinkPoRAdapter(
            address(aggregator),
            DEFAULT_STALENESS,
            DEFAULT_DEVIATION,
            admin
        );
    }

    // ===================================================================
    //  Constructor Tests
    // ===================================================================

    function test_Constructor_SetsImmutables() public view {
        assertEq(address(adapter.aggregator()), address(aggregator));
        assertEq(adapter.feedDecimals(), FEED_DECIMALS);
        assertEq(adapter.maxStaleness(), DEFAULT_STALENESS);
        assertEq(adapter.maxDeviation(), DEFAULT_DEVIATION);
    }

    function test_Constructor_GrantsRoles() public view {
        assertTrue(adapter.hasRole(adapter.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(adapter.hasRole(ADMIN_ROLE, admin));
    }

    function test_Constructor_SeedsPreviousAnswer() public view {
        // INITIAL_ANSWER is 1_000_000e8, scaled to 18 decimals = 1_000_000e18
        uint256 expected = uint256(uint256(INITIAL_ANSWER) * 1e10);
        assertEq(adapter.previousAnswer(), expected);
        assertEq(adapter.previousTimestamp(), block.timestamp);
    }

    function test_Constructor_RevertsOnZeroAggregator() public {
        vm.expectRevert(ChainlinkPoRAdapter.InvalidAggregator.selector);
        new ChainlinkPoRAdapter(address(0), DEFAULT_STALENESS, DEFAULT_DEVIATION, admin);
    }

    function test_Constructor_RevertsOnZeroAdmin() public {
        vm.expectRevert(ChainlinkPoRAdapter.InvalidAggregator.selector);
        new ChainlinkPoRAdapter(
            address(aggregator),
            DEFAULT_STALENESS,
            DEFAULT_DEVIATION,
            address(0)
        );
    }

    // ===================================================================
    //  getBackingAmount Tests
    // ===================================================================

    function test_GetBackingAmount_ScalesFrom8To18Decimals() public view {
        // aggregator returns 1_000_000e8 with 8 decimals
        // scaled to 18: 1_000_000e8 * 10^(18-8) = 1_000_000e18
        uint256 amount = adapter.getBackingAmount();
        assertEq(amount, 1_000_000e18);
    }

    function test_GetBackingAmount_WithDifferentValue() public {
        // Set answer to 500e8 (500 tokens in 8 decimals)
        aggregator.setAnswer(500e8);

        uint256 amount = adapter.getBackingAmount();
        assertEq(amount, 500e18);
    }

    function test_GetBackingAmount_RevertsOnZeroAnswer() public {
        aggregator.setAnswer(0);

        vm.expectRevert(ChainlinkPoRAdapter.ZeroAnswer.selector);
        adapter.getBackingAmount();
    }

    function test_GetBackingAmount_RevertsOnNegativeAnswer() public {
        aggregator.setAnswer(-1);

        vm.expectRevert(ChainlinkPoRAdapter.ZeroAnswer.selector);
        adapter.getBackingAmount();
    }

    function test_GetBackingAmount_RevertsOnStaleData() public {
        // Advance time past staleness threshold
        vm.warp(block.timestamp + DEFAULT_STALENESS + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ChainlinkPoRAdapter.StaleData.selector,
                1_700_000_000,   // updatedAt
                DEFAULT_STALENESS
            )
        );
        adapter.getBackingAmount();
    }

    function test_GetBackingAmount_SucceedsAtExactStalenessLimit() public {
        // Advance time to exactly the staleness threshold
        vm.warp(block.timestamp + DEFAULT_STALENESS);

        // Should not revert — block.timestamp - updatedAt == maxStaleness (not >)
        uint256 amount = adapter.getBackingAmount();
        assertEq(amount, 1_000_000e18);
    }

    // ===================================================================
    //  isHealthy Tests
    // ===================================================================

    function test_IsHealthy_ReturnsTrueWhenFresh() public view {
        assertTrue(adapter.isHealthy());
    }

    function test_IsHealthy_ReturnsFalseWhenStale() public {
        vm.warp(block.timestamp + DEFAULT_STALENESS + 1);
        assertFalse(adapter.isHealthy());
    }

    function test_IsHealthy_ReturnsFalseOnZeroAnswer() public {
        aggregator.setAnswer(0);
        assertFalse(adapter.isHealthy());
    }

    function test_IsHealthy_ReturnsFalseOnNegativeAnswer() public {
        aggregator.setAnswer(-100);
        assertFalse(adapter.isHealthy());
    }

    function test_IsHealthy_ReturnsFalseOnExcessiveDeviation() public {
        // previousAnswer is 1_000_000e18.
        // Set deviation threshold to 100 bps (1%).
        vm.prank(admin);
        adapter.setMaxDeviation(100);

        // Update the answer by more than 1% (e.g., 1_020_000e8 = 2% increase).
        aggregator.setAnswer(1_020_000e8);
        aggregator.setUpdatedAt(block.timestamp);

        assertFalse(adapter.isHealthy());
    }

    function test_IsHealthy_ReturnsTrueWhenDeviationWithinBounds() public {
        // previousAnswer is 1_000_000e18, maxDeviation is 500 bps (5%).
        // Set answer to 1_040_000e8 = 4% increase (within 5% threshold).
        aggregator.setAnswer(1_040_000e8);
        aggregator.setUpdatedAt(block.timestamp);

        assertTrue(adapter.isHealthy());
    }

    // ===================================================================
    //  lastUpdate Tests
    // ===================================================================

    function test_LastUpdate_ReturnsAggregatorTimestamp() public view {
        assertEq(adapter.lastUpdate(), block.timestamp);
    }

    function test_LastUpdate_ReflectsNewTimestamp() public {
        uint256 newTimestamp = block.timestamp + 100;
        aggregator.setUpdatedAt(newTimestamp);

        assertEq(adapter.lastUpdate(), newTimestamp);
    }

    // ===================================================================
    //  deviation Tests
    // ===================================================================

    function test_Deviation_ReturnsZeroWhenUnchanged() public view {
        // Current answer == previousAnswer, so deviation = 0
        assertEq(adapter.deviation(), 0);
    }

    function test_Deviation_CalculatesCorrectBps() public {
        // previousAnswer = 1_000_000e18
        // new answer = 1_050_000e8 => scaled = 1_050_000e18
        // deviation = |1_050_000 - 1_000_000| * 10000 / 1_000_000 = 500 bps
        aggregator.setAnswer(1_050_000e8);

        assertEq(adapter.deviation(), 500);
    }

    function test_Deviation_CalculatesNegativeChange() public {
        // previousAnswer = 1_000_000e18
        // new answer = 950_000e8 => scaled = 950_000e18
        // deviation = |950_000 - 1_000_000| * 10000 / 1_000_000 = 500 bps
        aggregator.setAnswer(950_000e8);

        assertEq(adapter.deviation(), 500);
    }

    function test_Deviation_ReturnsMaxOnZeroAnswer() public {
        aggregator.setAnswer(0);

        assertEq(adapter.deviation(), type(uint256).max);
    }

    function test_Deviation_ReturnsMaxOnNegativeAnswer() public {
        aggregator.setAnswer(-500);

        assertEq(adapter.deviation(), type(uint256).max);
    }

    // ===================================================================
    //  refreshPreviousAnswer Tests
    // ===================================================================

    function test_RefreshPreviousAnswer_UpdatesState() public {
        uint256 newTimestamp = block.timestamp + 60;
        aggregator.setAnswer(1_100_000e8);
        aggregator.setUpdatedAt(newTimestamp);

        adapter.refreshPreviousAnswer();

        // previousAnswer should now be 1_100_000e18
        assertEq(adapter.previousAnswer(), 1_100_000e18);
        assertEq(adapter.previousTimestamp(), newTimestamp);
    }

    function test_RefreshPreviousAnswer_EmitsBackingUpdated() public {
        uint256 newTimestamp = block.timestamp + 60;
        aggregator.setAnswer(1_100_000e8);
        aggregator.setUpdatedAt(newTimestamp);

        vm.expectEmit(true, true, false, true);
        emit BackingUpdated(1_100_000e18, block.timestamp, address(this));

        adapter.refreshPreviousAnswer();
    }

    function test_RefreshPreviousAnswer_NoOpWhenTimestampNotAdvanced() public {
        // updatedAt is the same as previousTimestamp — should not update
        uint256 prevAnswer = adapter.previousAnswer();
        uint256 prevTimestamp = adapter.previousTimestamp();

        aggregator.setAnswer(2_000_000e8);
        // Do NOT advance updatedAt

        adapter.refreshPreviousAnswer();

        assertEq(adapter.previousAnswer(), prevAnswer);
        assertEq(adapter.previousTimestamp(), prevTimestamp);
    }

    function test_RefreshPreviousAnswer_RevertsOnZeroAnswer() public {
        aggregator.setAnswer(0);

        vm.expectRevert(ChainlinkPoRAdapter.ZeroAnswer.selector);
        adapter.refreshPreviousAnswer();
    }

    function test_RefreshPreviousAnswer_NoEventWhenSameValue() public {
        // Advance timestamp but keep same answer — scaled value equals previousAnswer
        uint256 newTimestamp = block.timestamp + 60;
        aggregator.setUpdatedAt(newTimestamp);

        // No BackingUpdated event expected since scaled == previousAnswer
        vm.recordLogs();
        adapter.refreshPreviousAnswer();
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // No BackingUpdated events
        for (uint256 i = 0; i < entries.length; i++) {
            assertTrue(
                entries[i].topics[0] != keccak256("BackingUpdated(uint256,uint256,address)"),
                "Unexpected BackingUpdated event"
            );
        }
    }

    // ===================================================================
    //  setMaxStaleness Tests
    // ===================================================================

    function test_SetMaxStaleness_AdminCanUpdate() public {
        vm.prank(admin);
        adapter.setMaxStaleness(7200);

        assertEq(adapter.maxStaleness(), 7200);
    }

    function test_SetMaxStaleness_RevertsWithoutAdminRole() public {
        vm.prank(nonAdmin);
        vm.expectRevert();
        adapter.setMaxStaleness(7200);
    }

    function test_SetMaxStaleness_CanSetToZero() public {
        vm.prank(admin);
        adapter.setMaxStaleness(0);

        assertEq(adapter.maxStaleness(), 0);
    }

    // ===================================================================
    //  setMaxDeviation Tests
    // ===================================================================

    function test_SetMaxDeviation_AdminCanUpdate() public {
        vm.prank(admin);
        adapter.setMaxDeviation(1000);

        assertEq(adapter.maxDeviation(), 1000);
    }

    function test_SetMaxDeviation_RevertsWithoutAdminRole() public {
        vm.prank(nonAdmin);
        vm.expectRevert();
        adapter.setMaxDeviation(1000);
    }

    function test_SetMaxDeviation_CanSetToZero() public {
        vm.prank(admin);
        adapter.setMaxDeviation(0);

        assertEq(adapter.maxDeviation(), 0);
    }

    // ===================================================================
    //  MAX_STALENESS / MAX_DEVIATION Getters
    // ===================================================================

    function test_MaxStalenessGetter_ReturnsConfiguredValue() public view {
        assertEq(adapter.MAX_STALENESS(), DEFAULT_STALENESS);
    }

    function test_MaxDeviationGetter_ReturnsConfiguredValue() public view {
        assertEq(adapter.MAX_DEVIATION(), DEFAULT_DEVIATION);
    }

    // ===================================================================
    //  sourceCount / confidence Tests
    // ===================================================================

    function test_SourceCount_ReturnsOne() public view {
        assertEq(adapter.sourceCount(), 1);
    }

    function test_Confidence_Returns10000WhenHealthy() public view {
        assertEq(adapter.confidence(), 10_000);
    }

    function test_Confidence_Returns5000WhenStale() public {
        vm.warp(block.timestamp + DEFAULT_STALENESS + 1);

        assertEq(adapter.confidence(), 5000);
    }

    function test_Confidence_ReturnsZeroOnZeroAnswer() public {
        aggregator.setAnswer(0);

        assertEq(adapter.confidence(), 0);
    }
}
