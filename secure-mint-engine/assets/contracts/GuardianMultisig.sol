// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title GuardianMultisig
 * @author SecureMintEngine
 * @notice Lightweight multisig for guardian emergency actions (pause
 *         escalation). Purpose-built for SecureMintEngine, simpler than
 *         Gnosis Safe.
 *
 * @dev Transaction lifecycle:
 *
 *      1. Any owner calls `submitTransaction` to propose a new tx.
 *      2. Other owners call `confirmTransaction` to approve.
 *      3. When `confirmationCount >= required`, the tx auto-executes.
 *      4. Owners may `revokeConfirmation` before execution.
 *
 *      Self-governance functions (`addOwner`, `removeOwner`,
 *      `changeRequirement`) can only be invoked via the multisig itself
 *      (i.e., destination == address(this)).
 */
contract GuardianMultisig {
    // -------------------------------------------------------------------
    //  Custom Errors
    // -------------------------------------------------------------------

    /// @notice Caller is not a registered owner.
    error NotOwner(address caller);

    /// @notice The referenced transaction does not exist.
    error TxDoesNotExist(uint256 txId);

    /// @notice The caller has already confirmed this transaction.
    error AlreadyConfirmed(uint256 txId, address owner);

    /// @notice The caller has not confirmed this transaction.
    error NotConfirmed(uint256 txId, address owner);

    /// @notice The transaction has already been executed.
    error AlreadyExecuted(uint256 txId);

    /// @notice The low-level call for this transaction failed.
    error ExecutionFailed(uint256 txId);

    /// @notice The proposed requirement is invalid (0, or > owners.length).
    error InvalidRequirement(uint256 ownersCount, uint256 required);

    /// @notice The address is already a registered owner.
    error OwnerAlreadyExists(address owner);

    /// @notice The address is not a registered owner.
    error OwnerDoesNotExist(address owner);

    /// @notice A zero address was supplied where it is not allowed.
    error ZeroAddress();

    // -------------------------------------------------------------------
    //  Events
    // -------------------------------------------------------------------

    /// @notice Emitted when a new transaction is submitted.
    event Submission(uint256 indexed txId, address indexed submitter);

    /// @notice Emitted when an owner confirms a transaction.
    event Confirmation(uint256 indexed txId, address indexed owner);

    /// @notice Emitted when an owner revokes their confirmation.
    event Revocation(uint256 indexed txId, address indexed owner);

    /// @notice Emitted when a transaction is successfully executed.
    event Execution(uint256 indexed txId);

    /// @notice Emitted when a transaction execution fails.
    event ExecutionFailure(uint256 indexed txId);

    /// @notice Emitted when a new owner is added.
    event OwnerAdded(address indexed owner);

    /// @notice Emitted when an owner is removed.
    event OwnerRemoved(address indexed owner);

    /// @notice Emitted when the confirmation requirement is changed.
    event RequirementChanged(uint256 previousRequired, uint256 newRequired);

    // -------------------------------------------------------------------
    //  Structs
    // -------------------------------------------------------------------

    struct Transaction {
        address destination;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmationCount;
    }

    // -------------------------------------------------------------------
    //  State Variables
    // -------------------------------------------------------------------

    /// @notice Ordered list of multisig owners.
    address[] public owners;

    /// @notice Quick lookup for owner membership.
    mapping(address => bool) public isOwner;

    /// @notice Number of confirmations required to execute a transaction.
    uint256 public required;

    /// @notice Total number of transactions ever submitted.
    uint256 public transactionCount;

    /// @notice Transaction storage by ID.
    mapping(uint256 => Transaction) public transactions;

    /// @notice Confirmation state: txId => owner => confirmed.
    mapping(uint256 => mapping(address => bool)) public confirmations;

    // -------------------------------------------------------------------
    //  Modifiers
    // -------------------------------------------------------------------

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert NotOwner(msg.sender);
        _;
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "GuardianMultisig: only via multisig");
        _;
    }

    modifier txExists(uint256 txId) {
        if (txId >= transactionCount) revert TxDoesNotExist(txId);
        _;
    }

    modifier notExecuted(uint256 txId) {
        if (transactions[txId].executed) revert AlreadyExecuted(txId);
        _;
    }

    // -------------------------------------------------------------------
    //  Constructor
    // -------------------------------------------------------------------

    /**
     * @notice Deploys the GuardianMultisig with an initial set of owners
     *         and a confirmation threshold.
     * @param owners_   Array of initial owner addresses.
     * @param required_ Number of confirmations required to execute a tx.
     */
    constructor(address[] memory owners_, uint256 required_) {
        if (owners_.length == 0) revert InvalidRequirement(0, required_);
        if (required_ == 0 || required_ > owners_.length) {
            revert InvalidRequirement(owners_.length, required_);
        }

        for (uint256 i = 0; i < owners_.length; i++) {
            address owner = owners_[i];
            if (owner == address(0)) revert ZeroAddress();
            if (isOwner[owner]) revert OwnerAlreadyExists(owner);

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = required_;
    }

    // -------------------------------------------------------------------
    //  External — Transaction Lifecycle
    // -------------------------------------------------------------------

    /**
     * @notice Submits a new transaction for multisig approval.
     * @dev The submitter's confirmation is automatically recorded.
     * @param destination Target contract address.
     * @param value       ETH value to send with the call.
     * @param data        Calldata for the low-level call.
     * @return txId       The ID of the newly created transaction.
     */
    function submitTransaction(
        address destination,
        uint256 value,
        bytes calldata data
    ) external onlyOwner returns (uint256 txId) {
        txId = transactionCount;
        transactionCount++;

        transactions[txId] = Transaction({
            destination: destination,
            value: value,
            data: data,
            executed: false,
            confirmationCount: 0
        });

        emit Submission(txId, msg.sender);

        // Auto-confirm for the submitter
        _confirm(txId);
    }

    /**
     * @notice Confirms a pending transaction. If the threshold is met,
     *         the transaction is automatically executed.
     * @param txId The transaction ID to confirm.
     */
    function confirmTransaction(
        uint256 txId
    ) external onlyOwner txExists(txId) notExecuted(txId) {
        _confirm(txId);
    }

    /**
     * @notice Revokes a previously given confirmation (before execution).
     * @param txId The transaction ID to revoke confirmation for.
     */
    function revokeConfirmation(
        uint256 txId
    ) external onlyOwner txExists(txId) notExecuted(txId) {
        if (!confirmations[txId][msg.sender]) revert NotConfirmed(txId, msg.sender);

        confirmations[txId][msg.sender] = false;
        transactions[txId].confirmationCount--;

        emit Revocation(txId, msg.sender);
    }

    /**
     * @notice Executes a confirmed transaction if the threshold is met.
     * @dev Can be called explicitly if auto-execution did not trigger
     *      (e.g., gas estimation edge cases).
     * @param txId The transaction ID to execute.
     */
    function executeTransaction(
        uint256 txId
    ) external onlyOwner txExists(txId) notExecuted(txId) {
        _execute(txId);
    }

    // -------------------------------------------------------------------
    //  External — Self-Governance (only via multisig)
    // -------------------------------------------------------------------

    /**
     * @notice Adds a new owner to the multisig.
     * @dev Can only be called by the multisig itself (via an approved tx).
     * @param owner The address to add as an owner.
     */
    function addOwner(address owner) external onlySelf {
        if (owner == address(0)) revert ZeroAddress();
        if (isOwner[owner]) revert OwnerAlreadyExists(owner);

        isOwner[owner] = true;
        owners.push(owner);

        emit OwnerAdded(owner);
    }

    /**
     * @notice Removes an owner from the multisig. Adjusts `required`
     *         downward if it would exceed the new owner count.
     * @dev Can only be called by the multisig itself (via an approved tx).
     * @param owner The address to remove.
     */
    function removeOwner(address owner) external onlySelf {
        if (!isOwner[owner]) revert OwnerDoesNotExist(owner);

        isOwner[owner] = false;

        // Remove from the owners array by swapping with the last element
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                // slither-disable-next-line costly-loop
                owners.pop();
                break;
            }
        }

        // Adjust required if it now exceeds the owner count
        if (required > owners.length) {
            uint256 previousRequired = required;
            required = owners.length;
            emit RequirementChanged(previousRequired, required);
        }

        emit OwnerRemoved(owner);
    }

    /**
     * @notice Changes the confirmation threshold.
     * @dev Can only be called by the multisig itself (via an approved tx).
     * @param newRequired The new number of confirmations required.
     */
    function changeRequirement(uint256 newRequired) external onlySelf {
        if (newRequired == 0 || newRequired > owners.length) {
            revert InvalidRequirement(owners.length, newRequired);
        }

        uint256 previousRequired = required;
        required = newRequired;

        emit RequirementChanged(previousRequired, newRequired);
    }

    // -------------------------------------------------------------------
    //  External — View Functions
    // -------------------------------------------------------------------

    /**
     * @notice Returns the number of confirmations for a given transaction.
     * @param txId The transaction ID.
     * @return count The number of confirmations.
     */
    function getConfirmationCount(uint256 txId) external view returns (uint256 count) {
        return transactions[txId].confirmationCount;
    }

    /**
     * @notice Returns the total number of transactions, optionally filtered.
     * @param pending  Include pending (not yet executed) transactions.
     * @param executed Include executed transactions.
     * @return count   The number of matching transactions.
     */
    function getTransactionCount(
        bool pending,
        bool executed
    ) external view returns (uint256 count) {
        for (uint256 i = 0; i < transactionCount; i++) {
            if ((pending && !transactions[i].executed) || (executed && transactions[i].executed)) {
                count++;
            }
        }
    }

    /**
     * @notice Returns the full list of current owners.
     * @return The array of owner addresses.
     */
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    /**
     * @notice Checks whether a transaction has enough confirmations.
     * @param txId The transaction ID.
     * @return True if confirmationCount >= required.
     */
    function isConfirmed(uint256 txId) public view returns (bool) {
        return transactions[txId].confirmationCount >= required;
    }

    // -------------------------------------------------------------------
    //  Internal
    // -------------------------------------------------------------------

    /**
     * @dev Records a confirmation and auto-executes if the threshold is met.
     * @param txId The transaction ID to confirm.
     */
    function _confirm(uint256 txId) internal {
        if (confirmations[txId][msg.sender]) revert AlreadyConfirmed(txId, msg.sender);

        confirmations[txId][msg.sender] = true;
        transactions[txId].confirmationCount++;

        emit Confirmation(txId, msg.sender);

        // Auto-execute if threshold reached
        if (isConfirmed(txId)) {
            _execute(txId);
        }
    }

    /**
     * @dev Executes a transaction via low-level call.
     * @param txId The transaction ID to execute.
     */
    function _execute(uint256 txId) internal {
        Transaction storage txn = transactions[txId];

        if (!isConfirmed(txId)) revert NotConfirmed(txId, address(0));

        // CEI: set executed BEFORE the external call; if the call fails
        // the entire transaction reverts, rolling back this state change.
        txn.executed = true;

        // solhint-disable-next-line avoid-low-level-calls
        // slither-disable-next-line low-level-calls
        (bool success,) = txn.destination.call{value: txn.value}(txn.data);

        if (!success) revert ExecutionFailed(txId);

        // slither-disable-next-line reentrancy-events
        emit Execution(txId);
    }

    // -------------------------------------------------------------------
    //  Receive
    // -------------------------------------------------------------------

    /// @dev Allows the multisig to receive ETH (needed for value transfers).
    receive() external payable {}
}
