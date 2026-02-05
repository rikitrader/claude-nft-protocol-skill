// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/Timelock.sol";

/**
 * @title TimelockTest
 * @notice Unit tests for the Timelock time-delayed execution controller.
 */
contract TimelockTest is Test {
    // -------------------------------------------------------------------
    //  Events (declared locally for Solidity 0.8.20 emit compatibility)
    // -------------------------------------------------------------------

    event OperationScheduled(
        bytes32 indexed operationId,
        address indexed target,
        uint256 value,
        bytes data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 readyTimestamp
    );

    event OperationExecuted(bytes32 indexed operationId);

    event OperationCancelled(bytes32 indexed operationId);

    event MinDelayChange(uint256 previousDelay, uint256 newDelay);

    // -------------------------------------------------------------------
    //  State
    // -------------------------------------------------------------------

    Timelock public timelock;

    address public admin = makeAddr("admin");
    address public proposer = makeAddr("proposer");
    address public executor = makeAddr("executor");
    address public canceller = makeAddr("canceller");
    address public stranger = makeAddr("stranger");

    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 public constant MIN_DELAY = 1 days;

    // Default operation parameters
    address public target;
    uint256 public value = 0;
    bytes public data;
    bytes32 public predecessor = bytes32(0);
    bytes32 public salt = keccak256("salt_1");

    // -------------------------------------------------------------------
    //  Setup
    // -------------------------------------------------------------------

    function setUp() public {
        address[] memory proposers = new address[](1);
        proposers[0] = proposer;
        address[] memory executors = new address[](1);
        executors[0] = executor;
        address[] memory cancellers = new address[](1);
        cancellers[0] = canceller;

        timelock = new Timelock(MIN_DELAY, admin, proposers, executors, cancellers);

        // Default target is the timelock itself (for updateMinDelay tests)
        target = address(timelock);
        data = abi.encodeWithSelector(Timelock.updateMinDelay.selector, 2 days);
    }

    // -------------------------------------------------------------------
    //  Helper — schedule default operation
    // -------------------------------------------------------------------

    function _scheduleDefault() internal returns (bytes32) {
        vm.prank(proposer);
        timelock.schedule(target, value, data, predecessor, salt, MIN_DELAY);
        return timelock.hashOperation(target, value, data, predecessor, salt);
    }

    // -------------------------------------------------------------------
    //  Constructor Tests
    // -------------------------------------------------------------------

    function test_Constructor_SetsParamsCorrectly() public view {
        assertEq(timelock.minDelay(), MIN_DELAY);
        assertTrue(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(timelock.hasRole(ADMIN_ROLE, admin));
        assertTrue(timelock.hasRole(PROPOSER_ROLE, proposer));
        assertTrue(timelock.hasRole(EXECUTOR_ROLE, executor));
        assertTrue(timelock.hasRole(CANCELLER_ROLE, canceller));
    }

    function test_Constructor_RevertsZeroAdmin() public {
        address[] memory empty = new address[](0);
        vm.expectRevert("Timelock: zero admin");
        new Timelock(MIN_DELAY, address(0), empty, empty, empty);
    }

    function test_Constructor_AllowsZeroMinDelay() public {
        address[] memory empty = new address[](0);
        Timelock tl = new Timelock(0, admin, empty, empty, empty);
        assertEq(tl.minDelay(), 0);
    }

    // -------------------------------------------------------------------
    //  Schedule Tests
    // -------------------------------------------------------------------

    function test_Schedule_CreatesOperation() public {
        bytes32 id = _scheduleDefault();

        assertTrue(timelock.isOperation(id));
        assertTrue(timelock.isOperationPending(id));
        assertFalse(timelock.isOperationReady(id));
        assertFalse(timelock.isOperationDone(id));
        assertEq(timelock.getTimestamp(id), block.timestamp + MIN_DELAY);
    }

    function test_Schedule_EmitsOperationScheduled() public {
        bytes32 id = timelock.hashOperation(target, value, data, predecessor, salt);
        uint256 readyTimestamp = block.timestamp + MIN_DELAY;

        vm.prank(proposer);
        vm.expectEmit(true, true, false, true);
        emit OperationScheduled(id, target, value, data, predecessor, salt, readyTimestamp);
        timelock.schedule(target, value, data, predecessor, salt, MIN_DELAY);
    }

    function test_Schedule_RevertsInsufficientDelay() public {
        vm.prank(proposer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Timelock.TimelockInsufficientDelay.selector,
                MIN_DELAY - 1,
                MIN_DELAY
            )
        );
        timelock.schedule(target, value, data, predecessor, salt, MIN_DELAY - 1);
    }

    function test_Schedule_RevertsDuplicateOperation() public {
        _scheduleDefault();

        bytes32 id = timelock.hashOperation(target, value, data, predecessor, salt);

        vm.prank(proposer);
        vm.expectRevert(abi.encodeWithSelector(Timelock.TimelockAlreadyScheduled.selector, id));
        timelock.schedule(target, value, data, predecessor, salt, MIN_DELAY);
    }

    function test_Schedule_RevertsUnauthorized() public {
        vm.prank(stranger);
        vm.expectRevert();
        timelock.schedule(target, value, data, predecessor, salt, MIN_DELAY);
    }

    function test_Schedule_WithLargerDelay() public {
        uint256 largerDelay = 7 days;

        vm.prank(proposer);
        timelock.schedule(target, value, data, predecessor, salt, largerDelay);

        bytes32 id = timelock.hashOperation(target, value, data, predecessor, salt);
        assertEq(timelock.getTimestamp(id), block.timestamp + largerDelay);
    }

    // -------------------------------------------------------------------
    //  Execute Tests
    // -------------------------------------------------------------------

    function test_Execute_AfterDelay() public {
        bytes32 id = _scheduleDefault();

        // Warp past the delay
        vm.warp(block.timestamp + MIN_DELAY);

        assertTrue(timelock.isOperationReady(id));

        vm.prank(executor);
        vm.expectEmit(true, false, false, false);
        emit OperationExecuted(id);
        timelock.execute(target, value, data, predecessor, salt);

        assertTrue(timelock.isOperationDone(id));
        assertFalse(timelock.isOperationPending(id));
        // Verify the call worked: minDelay updated to 2 days
        assertEq(timelock.minDelay(), 2 days);
    }

    function test_Execute_RevertsTooEarly() public {
        bytes32 id = _scheduleDefault();

        // Do NOT warp — still too early
        vm.prank(executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                Timelock.TimelockNotReady.selector,
                id,
                block.timestamp + MIN_DELAY
            )
        );
        timelock.execute(target, value, data, predecessor, salt);
    }

    function test_Execute_RevertsNotPending() public {
        // Operation was never scheduled
        bytes32 id = timelock.hashOperation(target, value, data, predecessor, salt);

        vm.prank(executor);
        vm.expectRevert(abi.encodeWithSelector(Timelock.TimelockNotPending.selector, id));
        timelock.execute(target, value, data, predecessor, salt);
    }

    function test_Execute_RevertsAlreadyExecuted() public {
        _scheduleDefault();
        vm.warp(block.timestamp + MIN_DELAY);

        vm.prank(executor);
        timelock.execute(target, value, data, predecessor, salt);

        bytes32 id = timelock.hashOperation(target, value, data, predecessor, salt);

        vm.prank(executor);
        vm.expectRevert(abi.encodeWithSelector(Timelock.TimelockNotPending.selector, id));
        timelock.execute(target, value, data, predecessor, salt);
    }

    function test_Execute_RevertsUnauthorized() public {
        _scheduleDefault();
        vm.warp(block.timestamp + MIN_DELAY);

        vm.prank(stranger);
        vm.expectRevert();
        timelock.execute(target, value, data, predecessor, salt);
    }

    function test_Execute_RevertsCancelledOperation() public {
        bytes32 id = _scheduleDefault();
        vm.warp(block.timestamp + MIN_DELAY);

        vm.prank(canceller);
        timelock.cancel(id);

        vm.prank(executor);
        vm.expectRevert(abi.encodeWithSelector(Timelock.TimelockNotPending.selector, id));
        timelock.execute(target, value, data, predecessor, salt);
    }

    // -------------------------------------------------------------------
    //  Execute with Predecessor Tests
    // -------------------------------------------------------------------

    function test_Execute_WithPredecessor() public {
        // Schedule and execute operation A first
        bytes32 saltA = keccak256("salt_A");
        vm.prank(proposer);
        timelock.schedule(target, value, data, bytes32(0), saltA, MIN_DELAY);
        bytes32 idA = timelock.hashOperation(target, value, data, bytes32(0), saltA);

        vm.warp(block.timestamp + MIN_DELAY);
        vm.prank(executor);
        timelock.execute(target, value, data, bytes32(0), saltA);
        assertTrue(timelock.isOperationDone(idA));

        // Schedule operation B that depends on A
        bytes32 saltB = keccak256("salt_B");
        bytes memory dataB = abi.encodeWithSelector(Timelock.updateMinDelay.selector, 3 days);
        vm.prank(proposer);
        timelock.schedule(target, value, dataB, idA, saltB, timelock.minDelay());

        vm.warp(block.timestamp + timelock.minDelay());
        vm.prank(executor);
        timelock.execute(target, value, dataB, idA, saltB);
        assertEq(timelock.minDelay(), 3 days);
    }

    function test_Execute_RevertsPredecessorNotDone() public {
        // Schedule A but do NOT execute it
        bytes32 saltA = keccak256("salt_A");
        vm.prank(proposer);
        timelock.schedule(target, value, data, bytes32(0), saltA, MIN_DELAY);
        bytes32 idA = timelock.hashOperation(target, value, data, bytes32(0), saltA);

        // Schedule B with predecessor = idA
        bytes32 saltB = keccak256("salt_B");
        bytes memory dataB = abi.encodeWithSelector(Timelock.updateMinDelay.selector, 3 days);
        vm.prank(proposer);
        timelock.schedule(target, value, dataB, idA, saltB, MIN_DELAY);

        vm.warp(block.timestamp + MIN_DELAY);

        vm.prank(executor);
        vm.expectRevert(abi.encodeWithSelector(Timelock.TimelockUnexecutedPredecessor.selector, idA));
        timelock.execute(target, value, dataB, idA, saltB);
    }

    // -------------------------------------------------------------------
    //  Cancel Tests
    // -------------------------------------------------------------------

    function test_Cancel_PendingOperation() public {
        bytes32 id = _scheduleDefault();

        vm.prank(canceller);
        vm.expectEmit(true, false, false, false);
        emit OperationCancelled(id);
        timelock.cancel(id);

        assertFalse(timelock.isOperationPending(id));
        assertTrue(timelock.isOperation(id)); // still "exists" since readyTimestamp != 0
    }

    function test_Cancel_RevertsNotPending() public {
        bytes32 fakeId = keccak256("nonexistent");

        vm.prank(canceller);
        vm.expectRevert(abi.encodeWithSelector(Timelock.TimelockNotPending.selector, fakeId));
        timelock.cancel(fakeId);
    }

    function test_Cancel_RevertsUnauthorized() public {
        bytes32 id = _scheduleDefault();

        vm.prank(stranger);
        vm.expectRevert();
        timelock.cancel(id);
    }

    function test_Cancel_RevertsAlreadyExecuted() public {
        bytes32 id = _scheduleDefault();
        vm.warp(block.timestamp + MIN_DELAY);

        vm.prank(executor);
        timelock.execute(target, value, data, predecessor, salt);

        vm.prank(canceller);
        vm.expectRevert(abi.encodeWithSelector(Timelock.TimelockNotPending.selector, id));
        timelock.cancel(id);
    }

    // -------------------------------------------------------------------
    //  updateMinDelay Tests
    // -------------------------------------------------------------------

    function test_UpdateMinDelay_OnlySelf() public {
        vm.prank(admin);
        vm.expectRevert(Timelock.TimelockOnlySelf.selector);
        timelock.updateMinDelay(2 days);
    }

    function test_UpdateMinDelay_ViaSelfCall() public {
        // The default operation already calls updateMinDelay(2 days)
        _scheduleDefault();
        vm.warp(block.timestamp + MIN_DELAY);

        vm.prank(executor);
        timelock.execute(target, value, data, predecessor, salt);

        assertEq(timelock.minDelay(), 2 days);
    }

    function test_UpdateMinDelay_EmitsMinDelayChange() public {
        _scheduleDefault();
        vm.warp(block.timestamp + MIN_DELAY);

        vm.prank(executor);
        // The call to updateMinDelay will emit MinDelayChange
        vm.expectEmit(false, false, false, true);
        emit MinDelayChange(MIN_DELAY, 2 days);
        timelock.execute(target, value, data, predecessor, salt);
    }

    // -------------------------------------------------------------------
    //  State Query Tests
    // -------------------------------------------------------------------

    function test_IsOperation_FalseForNonExistent() public view {
        assertFalse(timelock.isOperation(keccak256("nope")));
    }

    function test_IsOperationPending_FalseForNonExistent() public view {
        assertFalse(timelock.isOperationPending(keccak256("nope")));
    }

    function test_IsOperationReady_FalseForNonExistent() public view {
        assertFalse(timelock.isOperationReady(keccak256("nope")));
    }

    function test_IsOperationDone_FalseForNonExistent() public view {
        assertFalse(timelock.isOperationDone(keccak256("nope")));
    }

    function test_IsOperationReady_TrueAtExactTimestamp() public {
        bytes32 id = _scheduleDefault();
        vm.warp(block.timestamp + MIN_DELAY); // exactly at readyTimestamp

        assertTrue(timelock.isOperationReady(id));
    }

    function test_IsOperationReady_FalseBeforeTimestamp() public {
        bytes32 id = _scheduleDefault();
        vm.warp(block.timestamp + MIN_DELAY - 1);

        assertFalse(timelock.isOperationReady(id));
    }

    // -------------------------------------------------------------------
    //  hashOperation Tests
    // -------------------------------------------------------------------

    function test_HashOperation_Consistency() public view {
        bytes32 hash1 = timelock.hashOperation(target, value, data, predecessor, salt);
        bytes32 hash2 = timelock.hashOperation(target, value, data, predecessor, salt);
        assertEq(hash1, hash2);
    }

    function test_HashOperation_DifferentSaltProducesDifferentId() public view {
        bytes32 hash1 = timelock.hashOperation(target, value, data, predecessor, keccak256("salt_1"));
        bytes32 hash2 = timelock.hashOperation(target, value, data, predecessor, keccak256("salt_2"));
        assertNotEq(hash1, hash2);
    }

    function test_HashOperation_MatchesExpected() public view {
        bytes32 expected = keccak256(abi.encode(target, value, data, predecessor, salt));
        bytes32 actual = timelock.hashOperation(target, value, data, predecessor, salt);
        assertEq(actual, expected);
    }

    // -------------------------------------------------------------------
    //  Receive ETH Tests
    // -------------------------------------------------------------------

    function test_ReceiveEth() public {
        vm.deal(admin, 5 ether);
        vm.prank(admin);
        (bool ok,) = address(timelock).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(timelock).balance, 1 ether);
    }
}
