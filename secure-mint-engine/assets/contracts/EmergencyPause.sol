// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title EmergencyPause
 * @author SecureMintEngine
 * @notice 4-level graduated circuit breaker for the SecureMintEngine protocol.
 *
 * @dev Pause Levels:
 *
 *      | Level | Name             | Effect                                  |
 *      |-------|------------------|-----------------------------------------|
 *      | L0    | NORMAL           | All operations permitted                |
 *      | L1    | MINT_PAUSED      | Minting halted; transfers allowed       |
 *      | L2    | RESTRICTED       | Minting + transfers halted              |
 *      | L3    | FULL_FREEZE      | All operations frozen; timelocked exit  |
 *
 *      Guardians can escalate the pause level. Only admins can de-escalate.
 *      Level 3 (full freeze) requires a timelock before it can be lifted.
 *      A DAO override can force de-escalation via DAO_ROLE.
 */
contract EmergencyPause is AccessControl {
    // -------------------------------------------------------------------
    //  Roles
    // -------------------------------------------------------------------

    /// @notice Guardians can escalate the pause level.
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    /// @notice Admins can de-escalate the pause level.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice DAO can force-override any pause level.
    bytes32 public constant DAO_ROLE = keccak256("DAO_ROLE");

    // -------------------------------------------------------------------
    //  Enums
    // -------------------------------------------------------------------

    enum PauseLevel {
        LEVEL_0_NORMAL,        // All operations permitted
        LEVEL_1_MINT_PAUSED,   // Minting halted
        LEVEL_2_RESTRICTED,    // Minting + transfers halted
        LEVEL_3_FULL_FREEZE    // Everything frozen
    }

    // -------------------------------------------------------------------
    //  Custom Errors
    // -------------------------------------------------------------------

    error CannotDeEscalateBelowNormal();
    error CannotDeEscalateToSameOrHigher(PauseLevel current, PauseLevel requested);
    error CannotEscalateToSameOrLower(PauseLevel current, PauseLevel requested);
    error FullFreezeTimelockActive(uint256 availableAt);
    error CooldownActive(uint256 cooldownEndsAt);
    error ZeroAddress();

    // -------------------------------------------------------------------
    //  Events
    // -------------------------------------------------------------------

    event PauseLevelChanged(
        PauseLevel indexed previousLevel,
        PauseLevel indexed newLevel,
        address indexed changedBy,
        string reason,
        uint256 timestamp
    );

    event FullFreezeTimelockStarted(uint256 availableAt);
    event DAOOverride(PauseLevel indexed newLevel, address indexed daoAddress);

    // -------------------------------------------------------------------
    //  State Variables
    // -------------------------------------------------------------------

    /// @notice The current pause level.
    PauseLevel public currentLevel;

    /// @notice Timelock delay for lifting a full freeze (seconds).
    uint256 public immutable fullFreezeTimelockDelay;

    /// @notice Timestamp when the full freeze timelock expires.
    uint256 public fullFreezeAvailableAt;

    /// @notice Cooldown period after any de-escalation (seconds).
    uint256 public immutable cooldownPeriod;

    /// @notice Timestamp when the cooldown expires.
    uint256 public cooldownEndsAt;

    /// @notice Address of the BackedToken contract (for integration hooks).
    address public immutable backedToken;

    /// @notice Address of the SecureMintPolicy contract (for integration hooks).
    address public immutable secureMintPolicy;

    // -------------------------------------------------------------------
    //  Constructor
    // -------------------------------------------------------------------

    /**
     * @param admin                    Initial admin address.
     * @param fullFreezeTimelockDelay_ Timelock delay for lifting full freeze (seconds).
     * @param cooldownPeriod_          Cooldown after de-escalation (seconds).
     * @param backedToken_             BackedToken contract address.
     * @param secureMintPolicy_        SecureMintPolicy contract address.
     */
    constructor(
        address admin,
        uint256 fullFreezeTimelockDelay_,
        uint256 cooldownPeriod_,
        address backedToken_,
        address secureMintPolicy_
    ) {
        require(admin != address(0), "EmergencyPause: zero admin");
        if (backedToken_ == address(0)) revert ZeroAddress();
        if (secureMintPolicy_ == address(0)) revert ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);

        fullFreezeTimelockDelay = fullFreezeTimelockDelay_;
        cooldownPeriod = cooldownPeriod_;
        backedToken = backedToken_;
        secureMintPolicy = secureMintPolicy_;
        currentLevel = PauseLevel.LEVEL_0_NORMAL;
    }

    // -------------------------------------------------------------------
    //  External — Escalation (GUARDIAN_ROLE)
    // -------------------------------------------------------------------

    /**
     * @notice Escalates the pause level. Can only go UP (higher severity).
     * @param newLevel The new, higher pause level.
     * @param reason   A human-readable reason for the escalation.
     */
    function escalate(
        PauseLevel newLevel,
        string calldata reason
    ) external onlyRole(GUARDIAN_ROLE) {
        if (newLevel <= currentLevel) {
            revert CannotEscalateToSameOrLower(currentLevel, newLevel);
        }

        PauseLevel previous = currentLevel;
        currentLevel = newLevel;

        if (newLevel == PauseLevel.LEVEL_3_FULL_FREEZE) {
            // slither-disable-next-line timestamp
            fullFreezeAvailableAt = block.timestamp + fullFreezeTimelockDelay;
            emit FullFreezeTimelockStarted(fullFreezeAvailableAt);
        }

        _notifyIntegrations();
        // slither-disable-next-line reentrancy-events
        emit PauseLevelChanged(previous, newLevel, msg.sender, reason, block.timestamp);
    }

    // -------------------------------------------------------------------
    //  External — De-escalation (ADMIN_ROLE)
    // -------------------------------------------------------------------

    /**
     * @notice De-escalates the pause level. Can only go DOWN (lower severity).
     * @dev If de-escalating from LEVEL_3, the timelock must have expired.
     *      After any de-escalation, a cooldown period is enforced.
     * @param newLevel The new, lower pause level.
     * @param reason   A human-readable reason for the de-escalation.
     */
    function deescalate(
        PauseLevel newLevel,
        string calldata reason
    ) external onlyRole(ADMIN_ROLE) {
        if (newLevel >= currentLevel) {
            revert CannotDeEscalateToSameOrHigher(currentLevel, newLevel);
        }

        // Enforce cooldown from previous de-escalation
        // slither-disable-next-line timestamp
        if (block.timestamp < cooldownEndsAt) {
            revert CooldownActive(cooldownEndsAt);
        }

        // Enforce full-freeze timelock
        if (currentLevel == PauseLevel.LEVEL_3_FULL_FREEZE) {
            // slither-disable-next-line timestamp
            if (block.timestamp < fullFreezeAvailableAt) {
                revert FullFreezeTimelockActive(fullFreezeAvailableAt);
            }
        }

        PauseLevel previous = currentLevel;
        currentLevel = newLevel;
        // slither-disable-next-line timestamp
        cooldownEndsAt = block.timestamp + cooldownPeriod;

        _notifyIntegrations();
        // slither-disable-next-line reentrancy-events
        emit PauseLevelChanged(previous, newLevel, msg.sender, reason, block.timestamp);
    }

    // -------------------------------------------------------------------
    //  External — DAO Override (DAO_ROLE)
    // -------------------------------------------------------------------

    /**
     * @notice DAO can force-set any pause level, bypassing timelock and cooldown.
     * @param newLevel The target pause level.
     */
    function daoOverride(PauseLevel newLevel) external onlyRole(DAO_ROLE) {
        PauseLevel previous = currentLevel;
        currentLevel = newLevel;
        cooldownEndsAt = 0;
        fullFreezeAvailableAt = 0;

        _notifyIntegrations();
        // slither-disable-next-line reentrancy-events
        emit DAOOverride(newLevel, msg.sender);
        // slither-disable-next-line reentrancy-events
        emit PauseLevelChanged(previous, newLevel, msg.sender, "DAO override", block.timestamp);
    }

    // -------------------------------------------------------------------
    //  External — View Helpers
    // -------------------------------------------------------------------

    /**
     * @notice Returns true if minting is currently paused (level >= 1).
     */
    function isMintPaused() external view returns (bool) {
        return currentLevel >= PauseLevel.LEVEL_1_MINT_PAUSED;
    }

    /**
     * @notice Returns true if transfers are currently paused (level >= 2).
     */
    function isTransferPaused() external view returns (bool) {
        return currentLevel >= PauseLevel.LEVEL_2_RESTRICTED;
    }

    /**
     * @notice Returns true if all operations are frozen (level == 3).
     */
    function isFullFreeze() external view returns (bool) {
        return currentLevel == PauseLevel.LEVEL_3_FULL_FREEZE;
    }

    // -------------------------------------------------------------------
    //  Internal — Integration Hooks
    // -------------------------------------------------------------------

    /**
     * @dev Notifies integrated contracts of the current pause level.
     *      Uses low-level calls to avoid reverting if the target does
     *      not implement the hook.
     */
    function _notifyIntegrations() internal {
        if (backedToken != address(0)) {
            // solhint-disable-next-line avoid-low-level-calls
            // slither-disable-next-line low-level-calls
            (bool success, ) = backedToken.call(
                abi.encodeWithSignature("onPauseLevelChanged(uint8)", uint8(currentLevel))
            );
            if (!success) {
                // slither-disable-next-line reentrancy-events
                emit IntegrationHookFailed(backedToken, "BackedToken.onPauseLevelChanged");
            }
        }

        if (secureMintPolicy != address(0)) {
            // solhint-disable-next-line avoid-low-level-calls
            // slither-disable-next-line low-level-calls
            (bool success, ) = secureMintPolicy.call(
                abi.encodeWithSignature("onPauseLevelChanged(uint8)", uint8(currentLevel))
            );
            if (!success) {
                // slither-disable-next-line reentrancy-events
                emit IntegrationHookFailed(secureMintPolicy, "SecureMintPolicy.onPauseLevelChanged");
            }
        }
    }

    /// @dev Emitted when an integration hook call fails (graceful degradation).
    event IntegrationHookFailed(address indexed target, string hookName);
}
