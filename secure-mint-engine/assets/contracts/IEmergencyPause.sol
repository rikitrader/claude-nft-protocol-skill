// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IEmergencyPause
 * @author SecureMintEngine
 * @notice Interface for the EmergencyPause contract — a 4-level graduated
 *         circuit breaker for the SecureMintEngine protocol.
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
interface IEmergencyPause {
    // -------------------------------------------------------------------
    //  Enums
    // -------------------------------------------------------------------

    /**
     * @notice The four graduated pause levels.
     */
    enum PauseLevel {
        LEVEL_0_NORMAL,        // All operations permitted
        LEVEL_1_MINT_PAUSED,   // Minting halted
        LEVEL_2_RESTRICTED,    // Minting + transfers halted
        LEVEL_3_FULL_FREEZE    // Everything frozen
    }

    // -------------------------------------------------------------------
    //  Events
    // -------------------------------------------------------------------

    /**
     * @notice Emitted when the pause level changes (escalation or de-escalation).
     * @param previousLevel The pause level before the change.
     * @param newLevel      The pause level after the change.
     * @param changedBy     The address that triggered the change.
     * @param reason        A human-readable reason for the change.
     * @param timestamp     The block timestamp of the change.
     */
    event PauseLevelChanged(
        PauseLevel indexed previousLevel,
        PauseLevel indexed newLevel,
        address indexed changedBy,
        string reason,
        uint256 timestamp
    );

    /**
     * @notice Emitted when a full freeze is activated, starting the timelock.
     * @param availableAt Timestamp after which the freeze can be lifted.
     */
    event FullFreezeTimelockStarted(uint256 availableAt);

    /**
     * @notice Emitted when the DAO forces a pause level override.
     * @param newLevel   The pause level set by the DAO.
     * @param daoAddress The DAO address that executed the override.
     */
    event DAOOverride(PauseLevel indexed newLevel, address indexed daoAddress);

    /**
     * @notice Emitted when an integration hook call fails (graceful degradation).
     * @param target   The address of the target contract.
     * @param hookName The name of the hook that failed.
     */
    event IntegrationHookFailed(address indexed target, string hookName);

    // -------------------------------------------------------------------
    //  External — Escalation (GUARDIAN_ROLE)
    // -------------------------------------------------------------------

    /**
     * @notice Escalates the pause level. Can only go UP (higher severity).
     * @dev Reverts if `newLevel` is the same as or lower than the current level.
     *      If escalating to LEVEL_3_FULL_FREEZE, a timelock is automatically
     *      started before the freeze can be lifted.
     * @param newLevel The new, higher pause level.
     * @param reason   A human-readable reason for the escalation.
     */
    function escalate(PauseLevel newLevel, string calldata reason) external;

    // -------------------------------------------------------------------
    //  External — De-escalation (ADMIN_ROLE)
    // -------------------------------------------------------------------

    /**
     * @notice De-escalates the pause level. Can only go DOWN (lower severity).
     * @dev If de-escalating from LEVEL_3, the full-freeze timelock must have
     *      expired. After any de-escalation, a cooldown period is enforced.
     * @param newLevel The new, lower pause level.
     * @param reason   A human-readable reason for the de-escalation.
     */
    function deescalate(PauseLevel newLevel, string calldata reason) external;

    // -------------------------------------------------------------------
    //  External — DAO Override (DAO_ROLE)
    // -------------------------------------------------------------------

    /**
     * @notice DAO can force-set any pause level, bypassing timelock and cooldown.
     * @param newLevel The target pause level.
     */
    function daoOverride(PauseLevel newLevel) external;

    // -------------------------------------------------------------------
    //  View Functions
    // -------------------------------------------------------------------

    /**
     * @notice Returns true if minting is currently paused (level >= 1).
     * @return True when the current level is LEVEL_1_MINT_PAUSED or higher.
     */
    function isMintPaused() external view returns (bool);

    /**
     * @notice Returns true if transfers are currently paused (level >= 2).
     * @return True when the current level is LEVEL_2_RESTRICTED or higher.
     */
    function isTransferPaused() external view returns (bool);

    /**
     * @notice Returns true if all operations are frozen (level == 3).
     * @return True when the current level is LEVEL_3_FULL_FREEZE.
     */
    function isFullFreeze() external view returns (bool);

    /**
     * @notice Returns the current pause level.
     * @return The active PauseLevel enum value.
     */
    function currentLevel() external view returns (PauseLevel);
}
