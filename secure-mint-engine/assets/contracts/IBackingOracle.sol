// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IBackingOracle
 * @author SecureMintEngine
 * @notice Interface for oracle contracts that report the backing amount,
 *         health status, freshness, and deviation for a backed token system.
 * @dev Implementations may wrap Chainlink Proof-of-Reserve feeds, custom
 *      attestation oracles, or on-chain treasury balance reporters.
 *
 *      The SecureMintPolicy contract queries this interface before every
 *      mint to verify that backing is provably sufficient.
 */
interface IBackingOracle {
    // -------------------------------------------------------------------
    //  Events
    // -------------------------------------------------------------------

    /**
     * @notice Emitted when the backing amount is updated.
     * @param newBacking   The new reported backing amount (base units).
     * @param timestamp    The block timestamp of the update.
     * @param reporter     The address that triggered the update.
     */
    event BackingUpdated(
        uint256 indexed newBacking,
        uint256 timestamp,
        address indexed reporter
    );

    /**
     * @notice Emitted when the oracle transitions to an unhealthy state.
     * @param reason       A short description of why the oracle is unhealthy.
     * @param timestamp    The block timestamp of the event.
     */
    event OracleUnhealthy(string reason, uint256 timestamp);

    // -------------------------------------------------------------------
    //  Constants (recommended defaults — implementors may override)
    // -------------------------------------------------------------------

    /**
     * @notice Maximum age (in seconds) before a backing report is considered
     *         stale. Default recommendation: 3600 (1 hour).
     * @return The staleness threshold in seconds.
     */
    // slither-disable-next-line naming-convention
    function MAX_STALENESS() external view returns (uint256);

    /**
     * @notice Maximum acceptable deviation (in basis points) between
     *         consecutive reports. Default recommendation: 500 (5%).
     * @return The deviation threshold in basis points (1 bp = 0.01%).
     */
    // slither-disable-next-line naming-convention
    function MAX_DEVIATION() external view returns (uint256);

    // -------------------------------------------------------------------
    //  Core View Functions
    // -------------------------------------------------------------------

    /**
     * @notice Returns the current reported backing amount in base units.
     * @dev This value represents the total verifiable reserves that back
     *      the token supply. It MUST be sourced from a trusted on-chain
     *      feed (e.g., Chainlink PoR) or an auditable attestation.
     * @return The backing amount in the collateral token's base units.
     */
    function getBackingAmount() external view returns (uint256);

    /**
     * @notice Returns whether the oracle considers itself in a healthy state.
     * @dev An oracle is healthy when:
     *      - The last report is not stale (age < MAX_STALENESS)
     *      - The last report's deviation is within bounds (< MAX_DEVIATION)
     *      - No circuit breaker or anomaly flag is active
     * @return True if the oracle is healthy, false otherwise.
     */
    function isHealthy() external view returns (bool);

    /**
     * @notice Returns the block timestamp of the last backing update.
     * @return The Unix timestamp of the most recent backing report.
     */
    function lastUpdate() external view returns (uint256);

    /**
     * @notice Returns the deviation of the last report relative to the
     *         previous report, expressed in basis points.
     * @dev A deviation of 0 means no change. 100 = 1%, 500 = 5%, etc.
     *      The SecureMintPolicy uses this to detect anomalous oracle
     *      updates that may indicate manipulation or data-feed issues.
     * @return The deviation in basis points.
     */
    function deviation() external view returns (uint256);

    // -------------------------------------------------------------------
    //  Extended View Functions (optional)
    // -------------------------------------------------------------------

    /**
     * @notice Returns the number of independent data sources aggregated
     *         into the current backing report.
     * @dev Implementations that use a single source may return 1.
     *      Multi-source implementations should return the count of
     *      sources that contributed to the latest aggregated value.
     * @return The number of data sources.
     */
    function sourceCount() external view returns (uint256);

    /**
     * @notice Returns the confidence level of the current report as a
     *         percentage scaled by 1e4 (i.e., 10000 = 100% confidence).
     * @dev This is optional. Implementations that do not track confidence
     *      should return 10000 (100%).
     * @return The confidence level in basis points (0–10000).
     */
    function confidence() external view returns (uint256);
}
