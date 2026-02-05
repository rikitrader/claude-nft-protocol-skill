// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IBackingOracle.sol";

/**
 * @title OracleRouter
 * @author SecureMintEngine
 * @notice Multi-oracle router with fallback logic that implements
 *         IBackingOracle. Maintains a primary oracle and an ordered list of
 *         fallback oracles. When the primary is unhealthy, the router
 *         automatically fails over to the first healthy fallback.
 *
 * @dev The router is designed to be the oracle address set on SecureMintPolicy.
 *      It transparently proxies IBackingOracle calls to the best available
 *      source, providing resilience against single-feed outages.
 *
 *      Confidence scoring:
 *        - 10000 (100%) if all healthy sources agree within 100 bps.
 *        - Scaled down proportionally by the number of disagreeing sources.
 */
contract OracleRouter is IBackingOracle, AccessControl {
    // -------------------------------------------------------------------
    //  Roles
    // -------------------------------------------------------------------

    /// @notice Admins can add/remove fallback oracles.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // -------------------------------------------------------------------
    //  Custom Errors
    // -------------------------------------------------------------------

    /// @notice No oracle in the source array is currently healthy.
    error NoHealthyOracle();

    /// @notice The oracle address has already been added to the router.
    error OracleAlreadyAdded(address oracle);

    /// @notice The supplied index is out of bounds for the fallback array.
    error InvalidIndex(uint256 index, uint256 length);

    // -------------------------------------------------------------------
    //  Events
    // -------------------------------------------------------------------

    /// @notice Emitted when the primary oracle is replaced.
    event PrimaryOracleChanged(
        address indexed previousPrimary,
        address indexed newPrimary
    );

    /// @notice Emitted when a fallback oracle is added.
    event FallbackAdded(address indexed oracle, uint256 index);

    /// @notice Emitted when a fallback oracle is removed.
    event FallbackRemoved(address indexed oracle, uint256 index);

    /// @notice Emitted when a query fails over from primary to a fallback.
    event OracleFailover(
        address indexed failedOracle,
        address indexed fallbackOracle,
        uint256 timestamp
    );

    // -------------------------------------------------------------------
    //  State Variables
    // -------------------------------------------------------------------

    /// @notice The primary oracle source.
    IBackingOracle public primaryOracle;

    /// @notice Ordered list of fallback oracle sources.
    IBackingOracle[] public fallbackOracles;

    /// @notice Quick-lookup to prevent duplicate additions.
    mapping(address => bool) public isSource;

    /// @notice Agreement threshold (basis points) for confidence scoring.
    uint256 public constant AGREEMENT_THRESHOLD_BPS = 100;

    // -------------------------------------------------------------------
    //  Constructor
    // -------------------------------------------------------------------

    /**
     * @param primaryOracle_ Address of the primary IBackingOracle.
     * @param admin          Initial admin address.
     */
    constructor(address primaryOracle_, address admin) {
        require(primaryOracle_ != address(0), "OracleRouter: zero primary");
        require(admin != address(0), "OracleRouter: zero admin");

        primaryOracle = IBackingOracle(primaryOracle_);
        isSource[primaryOracle_] = true;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    // -------------------------------------------------------------------
    //  External — Admin Management
    // -------------------------------------------------------------------

    /**
     * @notice Adds a fallback oracle to the end of the fallback list.
     * @param oracle Address of the IBackingOracle to add.
     */
    function addFallbackOracle(address oracle) external onlyRole(ADMIN_ROLE) {
        require(oracle != address(0), "OracleRouter: zero address");
        if (isSource[oracle]) revert OracleAlreadyAdded(oracle);

        isSource[oracle] = true;
        fallbackOracles.push(IBackingOracle(oracle));

        emit FallbackAdded(oracle, fallbackOracles.length - 1);
    }

    /**
     * @notice Removes a fallback oracle by index (swap-and-pop).
     * @param index The index in the fallbackOracles array to remove.
     */
    function removeFallbackOracle(uint256 index) external onlyRole(ADMIN_ROLE) {
        if (index >= fallbackOracles.length) {
            revert InvalidIndex(index, fallbackOracles.length);
        }

        address removed = address(fallbackOracles[index]);
        isSource[removed] = false;

        // Swap with last element and pop.
        uint256 lastIndex = fallbackOracles.length - 1;
        if (index != lastIndex) {
            fallbackOracles[index] = fallbackOracles[lastIndex];
        }
        fallbackOracles.pop();

        emit FallbackRemoved(removed, index);
    }

    /**
     * @notice Replaces the primary oracle.
     * @param newPrimary Address of the new primary IBackingOracle.
     */
    function setPrimaryOracle(address newPrimary) external onlyRole(ADMIN_ROLE) {
        require(newPrimary != address(0), "OracleRouter: zero address");

        address oldPrimary = address(primaryOracle);
        isSource[oldPrimary] = false;

        if (isSource[newPrimary]) revert OracleAlreadyAdded(newPrimary);

        primaryOracle = IBackingOracle(newPrimary);
        isSource[newPrimary] = true;

        emit PrimaryOracleChanged(oldPrimary, newPrimary);
    }

    // -------------------------------------------------------------------
    //  External — IBackingOracle Implementation
    // -------------------------------------------------------------------

    /// @inheritdoc IBackingOracle
    // slither-disable-next-line naming-convention
    function MAX_STALENESS() external view override returns (uint256) {
        return primaryOracle.MAX_STALENESS();
    }

    /// @inheritdoc IBackingOracle
    // slither-disable-next-line naming-convention
    function MAX_DEVIATION() external view override returns (uint256) {
        return primaryOracle.MAX_DEVIATION();
    }

    /**
     * @notice Returns the backing amount from the first healthy oracle source.
     * @dev This is a view function — failovers are silent. Use getBackingAmountWithFailover()
     *      for non-view variant that emits OracleFailover events.
     *      Tries the primary oracle first. If it is unhealthy, iterates
     *      through fallback oracles in order and returns the first healthy result.
     * @return The backing amount from the best available oracle.
     */
    function getBackingAmount() external view override returns (uint256) {
        // Try primary first.
        if (_isSourceHealthy(primaryOracle)) {
            return primaryOracle.getBackingAmount();
        }

        // Fallback iteration.
        uint256 len = fallbackOracles.length;
        // slither-disable-next-line calls-loop
        for (uint256 i = 0; i < len; i++) {
            if (_isSourceHealthy(fallbackOracles[i])) {
                return fallbackOracles[i].getBackingAmount();
            }
        }

        revert NoHealthyOracle();
    }

    /**
     * @notice Emitting variant of getBackingAmount for non-view callers
     *         that need the OracleFailover event.
     * @return The backing amount from the best available oracle.
     */
    function getBackingAmountWithFailover() external returns (uint256) {
        // Try primary first.
        if (_isSourceHealthy(primaryOracle)) {
            return primaryOracle.getBackingAmount();
        }

        // Fallback iteration.
        uint256 len = fallbackOracles.length;
        // slither-disable-next-line calls-loop
        for (uint256 i = 0; i < len; i++) {
            if (_isSourceHealthy(fallbackOracles[i])) {
                emit OracleFailover(
                    address(primaryOracle),
                    address(fallbackOracles[i]),
                    block.timestamp
                );
                return fallbackOracles[i].getBackingAmount();
            }
        }

        revert NoHealthyOracle();
    }

    /// @inheritdoc IBackingOracle
    function isHealthy() external view override returns (bool) {
        if (_isSourceHealthy(primaryOracle)) return true;

        uint256 len = fallbackOracles.length;
        for (uint256 i = 0; i < len; i++) {
            if (_isSourceHealthy(fallbackOracles[i])) return true;
        }

        return false;
    }

    /// @inheritdoc IBackingOracle
    function lastUpdate() external view override returns (uint256) {
        uint256 mostRecent = 0;

        if (_isSourceHealthy(primaryOracle)) {
            uint256 ts = primaryOracle.lastUpdate();
            if (ts > mostRecent) mostRecent = ts;
        }

        uint256 len = fallbackOracles.length;
        // slither-disable-next-line calls-loop
        for (uint256 i = 0; i < len; i++) {
            if (_isSourceHealthy(fallbackOracles[i])) {
                uint256 ts = fallbackOracles[i].lastUpdate();
                if (ts > mostRecent) mostRecent = ts;
            }
        }

        return mostRecent;
    }

    /// @inheritdoc IBackingOracle
    function deviation() external view override returns (uint256) {
        // Return deviation from primary if healthy.
        if (_isSourceHealthy(primaryOracle)) {
            return primaryOracle.deviation();
        }

        // Otherwise return deviation from first healthy fallback.
        uint256 len = fallbackOracles.length;
        // slither-disable-next-line calls-loop
        for (uint256 i = 0; i < len; i++) {
            if (_isSourceHealthy(fallbackOracles[i])) {
                return fallbackOracles[i].deviation();
            }
        }

        return type(uint256).max;
    }

    /// @inheritdoc IBackingOracle
    function sourceCount() external view override returns (uint256) {
        return 1 + fallbackOracles.length;
    }

    /**
     * @notice Returns the confidence level based on source agreement.
     * @dev Collects backing amounts from all healthy sources and measures
     *      pairwise agreement. If all healthy sources agree within
     *      AGREEMENT_THRESHOLD_BPS, returns 10000. Otherwise scales down
     *      proportionally by the ratio of agreeing sources.
     * @return The confidence level in basis points (0-10000).
     */
    function confidence() external view override returns (uint256) {
        uint256 len = fallbackOracles.length;
        uint256 totalSources = 1 + len;
        uint256 healthyCount = 0;
        uint256[] memory amounts = new uint256[](totalSources);

        // Collect healthy backing amounts.
        if (_isSourceHealthy(primaryOracle)) {
            amounts[healthyCount] = primaryOracle.getBackingAmount();
            healthyCount++;
        }

        // slither-disable-next-line calls-loop
        for (uint256 i = 0; i < len; i++) {
            if (_isSourceHealthy(fallbackOracles[i])) {
                amounts[healthyCount] = fallbackOracles[i].getBackingAmount();
                healthyCount++;
            }
        }

        // No healthy sources means zero confidence.
        if (healthyCount == 0) return 0;

        // Single source — confidence is that source's own confidence.
        if (healthyCount == 1) {
            if (_isSourceHealthy(primaryOracle)) {
                return primaryOracle.confidence();
            }
            // slither-disable-next-line calls-loop
            for (uint256 i = 0; i < len; i++) {
                if (_isSourceHealthy(fallbackOracles[i])) {
                    return fallbackOracles[i].confidence();
                }
            }
        }

        // Multiple sources — measure agreement against the first healthy value.
        uint256 refAmount = amounts[0];
        uint256 agreeing = 1; // The refAmount agrees with itself.

        for (uint256 j = 1; j < healthyCount; j++) {
            uint256 diff = amounts[j] > refAmount
                ? amounts[j] - refAmount
                : refAmount - amounts[j];

            uint256 deviationBps = refAmount > 0
                ? (diff * 10_000) / refAmount
                : 0;

            if (deviationBps <= AGREEMENT_THRESHOLD_BPS) {
                agreeing++;
            }
        }

        // Scale: 10000 if all agree, proportionally less otherwise.
        return (agreeing * 10_000) / healthyCount;
    }

    // -------------------------------------------------------------------
    //  External — View Helpers
    // -------------------------------------------------------------------

    /**
     * @notice Returns the number of fallback oracles.
     */
    function fallbackCount() external view returns (uint256) {
        return fallbackOracles.length;
    }

    /**
     * @notice Returns all sources (primary + fallbacks) as an address array.
     */
    function allSources() external view returns (address[] memory) {
        uint256 len = fallbackOracles.length;
        uint256 total = 1 + len;
        address[] memory sources = new address[](total);
        sources[0] = address(primaryOracle);
        for (uint256 i = 0; i < len; i++) {
            sources[i + 1] = address(fallbackOracles[i]);
        }
        return sources;
    }

    // -------------------------------------------------------------------
    //  Internal
    // -------------------------------------------------------------------

    /**
     * @dev Checks whether a source oracle reports itself as healthy.
     *      Uses a try/catch to gracefully handle reverts from broken oracles.
     * @param source The IBackingOracle to check.
     * @return True if the source is healthy, false otherwise.
     */
    function _isSourceHealthy(IBackingOracle source) internal view returns (bool) {
        try source.isHealthy() returns (bool healthy) {
            return healthy;
        } catch {
            return false;
        }
    }
}
