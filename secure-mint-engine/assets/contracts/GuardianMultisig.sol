// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title GuardianMultisig
 * @notice Lightweight multisig for emergency operations
 * @dev Designed for guardian-level actions (emergency pause, oracle failover).
 *      Uses a simple threshold-of-N scheme without complex proposal lifecycles.
 */
contract GuardianMultisig is ReentrancyGuard {
    // ═══════════════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Required number of confirmations to execute
    uint256 public threshold;

    /// @notice List of guardian addresses
    address[] public guardians;

    /// @notice Whether an address is a guardian
    mapping(address => bool) public isGuardian;

    /// @notice Transaction nonce for replay protection
    uint256 public nonce;

    struct Transaction {
        address target;
        uint256 value;
        bytes data;
        uint256 confirmations;
        bool executed;
        uint256 proposedAt;
        mapping(address => bool) confirmed;
    }

    /// @notice Pending transactions
    mapping(uint256 => Transaction) public transactions;

    /// @notice Transaction expiry duration
    uint256 public constant TX_EXPIRY = 7 days;

    /// @notice Next transaction ID
    uint256 public transactionCount;

    // ═══════════════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════════════

    event TransactionProposed(uint256 indexed txId, address indexed proposer, address target, bytes data);
    event TransactionConfirmed(uint256 indexed txId, address indexed guardian);
    event TransactionExecuted(uint256 indexed txId);
    event TransactionRevoked(uint256 indexed txId, address indexed guardian);
    event GuardianAdded(address indexed guardian);
    event GuardianRemoved(address indexed guardian);
    event ThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    // ═══════════════════════════════════════════════════════════════════════
    // MODIFIERS
    // ═══════════════════════════════════════════════════════════════════════

    modifier onlyGuardian() {
        require(isGuardian[msg.sender], "Not a guardian");
        _;
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "Only via multisig");
        _;
    }

    modifier txExists(uint256 txId) {
        require(txId < transactionCount, "TX does not exist");
        _;
    }

    modifier txNotExecuted(uint256 txId) {
        require(!transactions[txId].executed, "TX already executed");
        _;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════

    constructor(address[] memory _guardians, uint256 _threshold) {
        require(_guardians.length >= _threshold, "Invalid threshold");
        require(_threshold > 0, "Threshold must be > 0");

        for (uint256 i = 0; i < _guardians.length; i++) {
            address guardian = _guardians[i];
            require(guardian != address(0), "Invalid guardian");
            require(!isGuardian[guardian], "Duplicate guardian");

            isGuardian[guardian] = true;
            guardians.push(guardian);
        }

        threshold = _threshold;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // TRANSACTION LIFECYCLE
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Propose a new transaction
    function propose(
        address _target,
        uint256 _value,
        bytes calldata _data
    ) external onlyGuardian returns (uint256 txId) {
        require(_target != address(0), "Zero address target");

        txId = transactionCount++;

        Transaction storage t = transactions[txId];
        t.target = _target;
        t.value = _value;
        t.data = _data;
        t.confirmations = 1;
        t.proposedAt = block.timestamp;
        t.confirmed[msg.sender] = true;

        emit TransactionProposed(txId, msg.sender, _target, _data);
        emit TransactionConfirmed(txId, msg.sender);

        // Auto-execute if threshold is 1
        if (threshold == 1) {
            _execute(txId);
        }
    }

    /// @notice Confirm a pending transaction
    function confirm(uint256 txId)
        external
        nonReentrant
        onlyGuardian
        txExists(txId)
        txNotExecuted(txId)
    {
        Transaction storage t = transactions[txId];
        require(block.timestamp <= t.proposedAt + TX_EXPIRY, "TX expired");
        require(!t.confirmed[msg.sender], "Already confirmed");

        t.confirmed[msg.sender] = true;
        t.confirmations++;

        emit TransactionConfirmed(txId, msg.sender);

        // Auto-execute if threshold reached
        if (t.confirmations >= threshold) {
            _execute(txId);
        }
    }

    /// @notice Revoke a confirmation
    function revoke(uint256 txId)
        external
        onlyGuardian
        txExists(txId)
        txNotExecuted(txId)
    {
        Transaction storage t = transactions[txId];
        require(t.confirmed[msg.sender], "Not confirmed");

        t.confirmed[msg.sender] = false;
        t.confirmations--;

        emit TransactionRevoked(txId, msg.sender);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // GUARDIAN MANAGEMENT (only via multisig)
    // ═══════════════════════════════════════════════════════════════════════

    function addGuardian(address _guardian) external onlySelf {
        require(!isGuardian[_guardian], "Already guardian");
        require(_guardian != address(0), "Invalid address");

        isGuardian[_guardian] = true;
        guardians.push(_guardian);

        emit GuardianAdded(_guardian);
    }

    function removeGuardian(address _guardian) external onlySelf {
        require(isGuardian[_guardian], "Not guardian");
        require(guardians.length - 1 >= threshold, "Would break threshold");

        isGuardian[_guardian] = false;

        // Remove from array
        for (uint256 i = 0; i < guardians.length; i++) {
            if (guardians[i] == _guardian) {
                guardians[i] = guardians[guardians.length - 1];
                guardians.pop();
                break;
            }
        }

        emit GuardianRemoved(_guardian);
    }

    function updateThreshold(uint256 _threshold) external onlySelf {
        require(_threshold > 0 && _threshold <= guardians.length, "Invalid threshold");
        emit ThresholdUpdated(threshold, _threshold);
        threshold = _threshold;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    function getGuardians() external view returns (address[] memory) {
        return guardians;
    }

    function getGuardianCount() external view returns (uint256) {
        return guardians.length;
    }

    function isConfirmed(uint256 txId, address guardian) external view returns (bool) {
        return transactions[txId].confirmed[guardian];
    }

    // ═══════════════════════════════════════════════════════════════════════
    // INTERNAL
    // ═══════════════════════════════════════════════════════════════════════

    function _execute(uint256 txId) internal {
        Transaction storage t = transactions[txId];
        t.executed = true;

        (bool success, ) = t.target.call{value: t.value}(t.data);
        require(success, "Execution failed");

        emit TransactionExecuted(txId);
    }

    /// @notice Receive ETH
    receive() external payable {}
}
