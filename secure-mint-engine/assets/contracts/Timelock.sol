// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Timelock
 * @author SecureMintEngine
 * @notice Time-delayed execution controller for critical parameter changes
 *         in the SecureMintEngine protocol.
 *
 * @dev Operations flow through three phases:
 *
 *      1. Schedule — A PROPOSER queues an operation with a delay >= minDelay.
 *      2. Execute  — An EXECUTOR runs the operation once the ready timestamp
 *                    has passed and any predecessor operation is done.
 *      3. Cancel   — A CANCELLER can cancel any pending (non-executed) operation.
 *
 *      Operations are identified by a keccak256 hash of their parameters
 *      (target, value, data, predecessor, salt). The salt allows scheduling
 *      the same call multiple times with different IDs.
 *
 *      The minDelay can only be updated via a self-call, ensuring the
 *      change itself goes through the timelock.
 */
contract Timelock is AccessControl {
    // -------------------------------------------------------------------
    //  Roles
    // -------------------------------------------------------------------

    /// @notice Proposers can schedule new operations.
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");

    /// @notice Executors can execute ready operations.
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    /// @notice Cancellers can cancel pending operations.
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

    /// @notice Admins can manage role assignments.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // -------------------------------------------------------------------
    //  Structs
    // -------------------------------------------------------------------

    struct TimelockOperation {
        address target;
        uint256 value;
        bytes data;
        bytes32 predecessor;
        bytes32 salt;
        uint256 readyTimestamp;
        bool executed;
        bool cancelled;
    }

    // -------------------------------------------------------------------
    //  Custom Errors
    // -------------------------------------------------------------------

    /// @dev Thrown when the requested delay is below the minimum.
    error TimelockInsufficientDelay(uint256 delay, uint256 minDelay);

    /// @dev Thrown when trying to execute an operation that is not yet ready.
    error TimelockNotReady(bytes32 operationId, uint256 readyTimestamp);

    /// @dev Thrown when the operation is not in a pending state.
    error TimelockNotPending(bytes32 operationId);

    /// @dev Thrown when trying to schedule an operation that already exists.
    error TimelockAlreadyScheduled(bytes32 operationId);

    /// @dev Thrown when a predecessor operation has not been executed.
    error TimelockUnexecutedPredecessor(bytes32 predecessorId);

    /// @dev Thrown when the low-level call to the target contract fails.
    error TimelockExecutionFailed(bytes32 operationId);

    /// @dev Thrown when updateMinDelay is called by an external account
    ///      rather than through the timelock itself.
    error TimelockOnlySelf();

    /// @dev Thrown when a zero address is provided where a non-zero address is required.
    error ZeroAddress();

    // -------------------------------------------------------------------
    //  Events
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
    //  State Variables
    // -------------------------------------------------------------------

    /// @notice Minimum delay (in seconds) that must elapse before an operation
    ///         becomes executable.
    uint256 public minDelay;

    /// @notice Mapping from operation ID to its full operation data.
    mapping(bytes32 => TimelockOperation) public operations;

    // -------------------------------------------------------------------
    //  Constructor
    // -------------------------------------------------------------------

    /**
     * @param minDelay_ Initial minimum delay in seconds.
     * @param admin     Initial admin address (receives DEFAULT_ADMIN_ROLE and ADMIN_ROLE).
     * @param proposers Array of addresses to receive PROPOSER_ROLE.
     * @param executors Array of addresses to receive EXECUTOR_ROLE.
     * @param cancellers Array of addresses to receive CANCELLER_ROLE.
     */
    constructor(
        uint256 minDelay_,
        address admin,
        address[] memory proposers,
        address[] memory executors,
        address[] memory cancellers
    ) {
        require(admin != address(0), "Timelock: zero admin");

        minDelay = minDelay_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);

        for (uint256 i = 0; i < proposers.length; i++) {
            if (proposers[i] == address(0)) revert ZeroAddress();
            _grantRole(PROPOSER_ROLE, proposers[i]);
        }
        for (uint256 i = 0; i < executors.length; i++) {
            if (executors[i] == address(0)) revert ZeroAddress();
            _grantRole(EXECUTOR_ROLE, executors[i]);
        }
        for (uint256 i = 0; i < cancellers.length; i++) {
            if (cancellers[i] == address(0)) revert ZeroAddress();
            _grantRole(CANCELLER_ROLE, cancellers[i]);
        }

        emit MinDelayChange(0, minDelay_);
    }

    // -------------------------------------------------------------------
    //  External — Schedule
    // -------------------------------------------------------------------

    /**
     * @notice Schedules a new timelocked operation.
     * @dev The delay must be >= minDelay. The operation ID is computed from
     *      (target, value, data, predecessor, salt) and must not already exist.
     * @param target      Address of the contract to call.
     * @param value       ETH value to send with the call.
     * @param data        Encoded function call data.
     * @param predecessor Operation ID that must be executed first (0x0 for none).
     * @param salt        Arbitrary salt to differentiate otherwise identical operations.
     * @param delay       Time in seconds before the operation becomes ready.
     */
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external onlyRole(PROPOSER_ROLE) {
        if (delay < minDelay) {
            revert TimelockInsufficientDelay(delay, minDelay);
        }

        bytes32 id = hashOperation(target, value, data, predecessor, salt);

        if (operations[id].readyTimestamp != 0) {
            revert TimelockAlreadyScheduled(id);
        }

        // slither-disable-next-line timestamp
        uint256 readyTimestamp = block.timestamp + delay;

        operations[id] = TimelockOperation({
            target: target,
            value: value,
            data: data,
            predecessor: predecessor,
            salt: salt,
            readyTimestamp: readyTimestamp,
            executed: false,
            cancelled: false
        });

        emit OperationScheduled(id, target, value, data, predecessor, salt, readyTimestamp);
    }

    // -------------------------------------------------------------------
    //  External — Execute
    // -------------------------------------------------------------------

    /**
     * @notice Executes a ready timelocked operation.
     * @dev The operation must be pending, past its readyTimestamp, and any
     *      predecessor must already be executed.
     * @param target      Address of the contract to call.
     * @param value       ETH value to send with the call.
     * @param data        Encoded function call data.
     * @param predecessor Operation ID that must be executed first (0x0 for none).
     * @param salt        Salt used when scheduling.
     */
    function execute(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    // slither-disable-next-line missing-zero-check
    ) external payable onlyRole(EXECUTOR_ROLE) {
        bytes32 id = hashOperation(target, value, data, predecessor, salt);

        if (!isOperationPending(id)) {
            revert TimelockNotPending(id);
        }

        if (!isOperationReady(id)) {
            revert TimelockNotReady(id, operations[id].readyTimestamp);
        }

        // Check predecessor (0x0 means no predecessor required)
        // slither-disable-next-line timestamp
        if (predecessor != bytes32(0) && !isOperationDone(predecessor)) {
            revert TimelockUnexecutedPredecessor(predecessor);
        }

        operations[id].executed = true;

        // solhint-disable-next-line avoid-low-level-calls
        // slither-disable-next-line arbitrary-send-eth,low-level-calls
        (bool success, ) = target.call{value: value}(data);
        if (!success) {
            revert TimelockExecutionFailed(id);
        }

        // slither-disable-next-line reentrancy-events
        emit OperationExecuted(id);
    }

    // -------------------------------------------------------------------
    //  External — Cancel
    // -------------------------------------------------------------------

    /**
     * @notice Cancels a pending operation.
     * @param id The operation identifier to cancel.
     */
    function cancel(bytes32 id) external onlyRole(CANCELLER_ROLE) {
        if (!isOperationPending(id)) {
            revert TimelockNotPending(id);
        }

        operations[id].cancelled = true;

        emit OperationCancelled(id);
    }

    // -------------------------------------------------------------------
    //  External — Configuration (self-call only)
    // -------------------------------------------------------------------

    /**
     * @notice Updates the minimum delay for future operations.
     * @dev Can only be called by the Timelock contract itself, meaning
     *      this change must go through schedule + execute.
     * @param newDelay The new minimum delay in seconds.
     */
    function updateMinDelay(uint256 newDelay) external {
        if (msg.sender != address(this)) {
            revert TimelockOnlySelf();
        }

        uint256 previousDelay = minDelay;
        minDelay = newDelay;

        emit MinDelayChange(previousDelay, newDelay);
    }

    // -------------------------------------------------------------------
    //  External — View Functions
    // -------------------------------------------------------------------

    /**
     * @notice Checks whether an operation exists (has been scheduled).
     * @param id The operation identifier.
     * @return True if the operation has been scheduled.
     */
    function isOperation(bytes32 id) public view returns (bool) {
        // slither-disable-next-line timestamp
        return operations[id].readyTimestamp != 0;
    }

    /**
     * @notice Checks whether an operation is pending (exists, not executed,
     *         not cancelled).
     * @param id The operation identifier.
     * @return True if the operation is pending.
     */
    function isOperationPending(bytes32 id) public view returns (bool) {
        // slither-disable-next-line timestamp
        return isOperation(id)
            && !operations[id].executed
            && !operations[id].cancelled;
    }

    /**
     * @notice Checks whether a pending operation is ready to execute.
     * @param id The operation identifier.
     * @return True if the operation is pending and block.timestamp >= readyTimestamp.
     */
    function isOperationReady(bytes32 id) public view returns (bool) {
        // slither-disable-next-line timestamp
        return isOperationPending(id)
            && block.timestamp >= operations[id].readyTimestamp;
    }

    /**
     * @notice Checks whether an operation has been executed.
     * @param id The operation identifier.
     * @return True if the operation was executed.
     */
    function isOperationDone(bytes32 id) public view returns (bool) {
        return operations[id].executed;
    }

    /**
     * @notice Returns the readyTimestamp for a given operation.
     * @param id The operation identifier.
     * @return The timestamp at which the operation becomes executable.
     */
    function getTimestamp(bytes32 id) external view returns (uint256) {
        return operations[id].readyTimestamp;
    }

    // -------------------------------------------------------------------
    //  Public — Pure Functions
    // -------------------------------------------------------------------

    /**
     * @notice Computes the operation ID from its parameters.
     * @param target      Target contract address.
     * @param value       ETH value.
     * @param data        Encoded calldata.
     * @param predecessor Predecessor operation ID.
     * @param salt        Salt value.
     * @return The keccak256 hash serving as the operation identifier.
     */
    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(target, value, data, predecessor, salt));
    }

    // -------------------------------------------------------------------
    //  Receive
    // -------------------------------------------------------------------

    /// @dev Allow the contract to receive ETH (needed for operations with value).
    receive() external payable {}
}
