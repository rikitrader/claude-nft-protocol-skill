// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ISecureMintPolicy
 * @author SecureMintEngine
 * @notice Interface for the SecureMintPolicy contract — the oracle-gated mint
 *         policy that enforces ALL conditions before any token can be minted.
 * @dev Mint Conditions (ALL must hold for mint() to succeed):
 *
 *      1. Verified backing >= post-mint totalSupply
 *      2. Oracle reports healthy (isHealthy() == true)
 *      3. Oracle data is not stale (age < maxStaleness)
 *      4. Oracle deviation is within bounds (< maxDeviation)
 *      5. Mint amount <= per-epoch rate limit
 *      6. totalSupply + amount <= global supply cap
 *      7. Contract is NOT paused
 *      8. Caller has OPERATOR_ROLE
 *
 *      Configuration changes (caps, oracle address) are timelocked.
 */
interface ISecureMintPolicy {
    // -------------------------------------------------------------------
    //  Events
    // -------------------------------------------------------------------

    /**
     * @notice Emitted after a successful mint operation.
     * @param to             Recipient of the minted tokens.
     * @param amount         Number of tokens minted.
     * @param newTotalSupply The total supply after the mint.
     * @param oracleBacking  The oracle-reported backing at mint time.
     * @param timestamp      The block timestamp of the mint.
     */
    event Minted(
        address indexed to,
        uint256 amount,
        uint256 newTotalSupply,
        uint256 oracleBacking,
        uint256 timestamp
    );

    /**
     * @notice Emitted when an epoch resets and the rate-limit counter is cleared.
     * @param epochNumber The new epoch number.
     * @param timestamp   The block timestamp of the reset.
     */
    event EpochReset(
        uint256 indexed epochNumber,
        uint256 timestamp
    );

    /**
     * @notice Emitted when a timelocked configuration change is proposed.
     * @param changeId    Unique identifier for the pending change.
     * @param description Human-readable description of the change.
     * @param availableAt Timestamp after which the change can be executed.
     */
    event ConfigChangeProposed(
        bytes32 indexed changeId,
        string description,
        uint256 availableAt
    );

    /**
     * @notice Emitted when a timelocked configuration change is executed.
     * @param changeId The identifier of the executed change.
     */
    event ConfigChangeExecuted(bytes32 indexed changeId);

    /**
     * @notice Emitted when a pending timelocked change is cancelled.
     * @param changeId The identifier of the cancelled change.
     */
    event ConfigChangeCancelled(bytes32 indexed changeId);

    // -------------------------------------------------------------------
    //  External — Mint (OPERATOR_ROLE only)
    // -------------------------------------------------------------------

    /**
     * @notice Mints `amount` tokens to `to` after verifying ALL conditions.
     * @dev Reverts if any of the mint conditions fail.
     * @param to     Recipient address.
     * @param amount Number of tokens to mint (base units).
     */
    function mint(address to, uint256 amount) external;

    // -------------------------------------------------------------------
    //  External — Pause Management
    // -------------------------------------------------------------------

    /**
     * @notice Emergency pause — immediately halts all minting.
     * @dev Callable only by GUARDIAN_ROLE.
     */
    function pause() external;

    /**
     * @notice Unpause minting operations.
     * @dev Callable only by ADMIN_ROLE.
     */
    function unpause() external;

    /**
     * @notice Called by EmergencyPause when pause level changes.
     * @dev Level 0: unpause minting. Level 1+: pause minting.
     *      Only callable by the registered EmergencyPause contract.
     * @param level The new pause level (0=Normal, 1=MintPaused, 2=Restricted, 3=FullFreeze).
     */
    function onPauseLevelChanged(uint8 level) external;

    // -------------------------------------------------------------------
    //  External — Timelocked Configuration (ADMIN_ROLE only)
    // -------------------------------------------------------------------

    /**
     * @notice Proposes a change to the global supply cap (timelocked).
     * @param newCap The new global supply cap.
     */
    function proposeGlobalCapChange(uint256 newCap) external;

    /**
     * @notice Executes a previously proposed global cap change.
     * @param changeId The change identifier from the proposal event.
     */
    function executeGlobalCapChange(bytes32 changeId) external;

    /**
     * @notice Proposes a change to the epoch mint cap (timelocked).
     * @param newCap The new epoch mint cap.
     */
    function proposeEpochCapChange(uint256 newCap) external;

    /**
     * @notice Executes a previously proposed epoch cap change.
     * @param changeId The change identifier from the proposal event.
     */
    function executeEpochCapChange(bytes32 changeId) external;

    /**
     * @notice Proposes a change to the oracle address (timelocked).
     * @param newOracle The new oracle address.
     */
    function proposeOracleChange(address newOracle) external;

    /**
     * @notice Executes a previously proposed oracle change.
     * @param changeId The change identifier from the proposal event.
     */
    function executeOracleChange(bytes32 changeId) external;

    /**
     * @notice Proposes a change to the maxStaleness threshold (timelocked).
     * @param newMaxStaleness The new maxStaleness value in seconds.
     */
    function proposeMaxStalenessChange(uint256 newMaxStaleness) external;

    /**
     * @notice Executes a previously proposed maxStaleness change.
     * @param changeId The change identifier from the proposal event.
     */
    function executeMaxStalenessChange(bytes32 changeId) external;

    /**
     * @notice Proposes a change to the maxDeviation threshold (timelocked).
     * @param newMaxDeviation The new maxDeviation value in basis points.
     */
    function proposeMaxDeviationChange(uint256 newMaxDeviation) external;

    /**
     * @notice Executes a previously proposed maxDeviation change.
     * @param changeId The change identifier from the proposal event.
     */
    function executeMaxDeviationChange(bytes32 changeId) external;

    /**
     * @notice Proposes a change to the epochDuration (timelocked).
     * @param newEpochDuration The new epoch duration in seconds.
     */
    function proposeEpochDurationChange(uint256 newEpochDuration) external;

    /**
     * @notice Executes a previously proposed epochDuration change.
     * @param changeId The change identifier from the proposal event.
     */
    function executeEpochDurationChange(bytes32 changeId) external;

    /**
     * @notice One-time initializer for the EmergencyPause contract address.
     * @dev After initial setup, use proposeEmergencyPauseChange/executeEmergencyPauseChange.
     * @param emergencyPause_ Address of the EmergencyPause contract.
     */
    function setEmergencyPause(address emergencyPause_) external;

    /**
     * @notice Proposes a timelocked change to the EmergencyPause contract address.
     * @param newPause The new EmergencyPause contract address.
     */
    function proposeEmergencyPauseChange(address newPause) external;

    /**
     * @notice Executes a previously proposed EmergencyPause address change.
     * @param changeId The change identifier from the proposal event.
     */
    function executeEmergencyPauseChange(bytes32 changeId) external;

    /**
     * @notice Cancels a pending timelocked change.
     * @param changeId The change identifier to cancel.
     */
    function cancelChange(bytes32 changeId) external;

    // -------------------------------------------------------------------
    //  View Functions
    // -------------------------------------------------------------------

    /**
     * @notice Returns the remaining mintable amount in the current epoch.
     * @return The number of tokens that can still be minted this epoch.
     */
    function epochRemaining() external view returns (uint256);

    /**
     * @notice Returns the remaining amount under the global supply cap.
     * @return The number of tokens that can still be minted globally.
     *         Returns type(uint256).max if globalSupplyCap is 0 (unlimited).
     */
    function globalRemaining() external view returns (uint256);

    /**
     * @notice Returns the address of the BackedToken contract.
     * @return The BackedToken contract address.
     */
    function backedToken() external view returns (address);

    /**
     * @notice Returns the address of the IBackingOracle implementation.
     * @return The oracle contract address.
     */
    function oracle() external view returns (address);

    /**
     * @notice Returns the global maximum supply cap (base units). 0 = unlimited.
     * @return The global supply cap.
     */
    function globalSupplyCap() external view returns (uint256);

    /**
     * @notice Returns the maximum tokens that can be minted per epoch (base units).
     * @return The epoch mint cap.
     */
    function epochMintCap() external view returns (uint256);

    /**
     * @notice Returns the duration of a single epoch in seconds.
     * @return The epoch duration.
     */
    function epochDuration() external view returns (uint256);

    /**
     * @notice Returns the maximum staleness for oracle data (seconds).
     * @return The staleness threshold.
     */
    function maxStaleness() external view returns (uint256);

    /**
     * @notice Returns the maximum acceptable oracle deviation (basis points).
     * @return The deviation threshold.
     */
    function maxDeviation() external view returns (uint256);
}
