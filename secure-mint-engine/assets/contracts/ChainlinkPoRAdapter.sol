// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IBackingOracle.sol";

/**
 * @title AggregatorV3Interface
 * @notice Minimal Chainlink AggregatorV3 interface for Proof-of-Reserve feeds.
 */
interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function decimals() external view returns (uint8);
}

/**
 * @title ChainlinkPoRAdapter
 * @author SecureMintEngine
 * @notice Adapter that wraps a Chainlink Proof-of-Reserve (PoR)
 *         AggregatorV3Interface feed and implements IBackingOracle.
 *
 * @dev This contract reads the latest round data from a Chainlink PoR
 *      aggregator, normalises the answer to 18 decimals, and exposes it
 *      through the IBackingOracle interface consumed by SecureMintPolicy.
 *
 *      Health is determined by two conditions:
 *        1. Staleness — block.timestamp - updatedAt <= maxStaleness
 *        2. Deviation — |current - previous| / previous <= maxDeviation
 *
 *      The adapter stores the previous answer on each call to
 *      getBackingAmount() so that deviation can be tracked across rounds.
 */
contract ChainlinkPoRAdapter is IBackingOracle, AccessControl {
    // -------------------------------------------------------------------
    //  Roles
    // -------------------------------------------------------------------

    /// @notice Admins can update maxStaleness and maxDeviation thresholds.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // -------------------------------------------------------------------
    //  Custom Errors
    // -------------------------------------------------------------------

    /// @notice The aggregator returned data older than the staleness threshold.
    error StaleData(uint256 updatedAt, uint256 maxAge);

    /// @notice The aggregator returned a zero or negative answer.
    error ZeroAnswer();

    /// @notice The supplied aggregator address is the zero address.
    error InvalidAggregator();

    /// @notice A zero address was provided where a non-zero address is required.
    error ZeroAddress();

    // -------------------------------------------------------------------
    //  State Variables
    // -------------------------------------------------------------------

    /// @notice The Chainlink PoR aggregator feed.
    AggregatorV3Interface public immutable aggregator;

    /// @notice Number of decimals reported by the aggregator feed.
    uint8 public immutable feedDecimals;

    /// @notice Maximum age (in seconds) before data is considered stale.
    uint256 public maxStaleness;

    /// @notice Maximum acceptable deviation (basis points) between updates.
    uint256 public maxDeviation;

    /// @notice The previous answer stored for deviation calculation.
    uint256 public previousAnswer;

    /// @notice The timestamp of the previous answer.
    uint256 public previousTimestamp;

    // -------------------------------------------------------------------
    //  Constructor
    // -------------------------------------------------------------------

    /**
     * @param aggregator_    Address of the Chainlink PoR AggregatorV3 feed.
     * @param maxStaleness_  Maximum staleness threshold in seconds.
     * @param maxDeviation_  Maximum deviation threshold in basis points.
     * @param admin          Initial admin address.
     */
    constructor(
        address aggregator_,
        uint256 maxStaleness_,
        uint256 maxDeviation_,
        address admin
    ) {
        if (aggregator_ == address(0)) revert InvalidAggregator();
        if (admin == address(0)) revert ZeroAddress();

        aggregator = AggregatorV3Interface(aggregator_);
        feedDecimals = AggregatorV3Interface(aggregator_).decimals();
        maxStaleness = maxStaleness_;
        maxDeviation = maxDeviation_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);

        // Seed previousAnswer from the current feed value.
        // slither-disable-next-line unused-return
        (, int256 answer,, uint256 updatedAt,) = AggregatorV3Interface(aggregator_).latestRoundData();
        if (answer > 0) {
            previousAnswer = _scaleTo18(uint256(answer));
            previousTimestamp = updatedAt;
        }
    }

    // -------------------------------------------------------------------
    //  External — IBackingOracle Implementation
    // -------------------------------------------------------------------

    /// @inheritdoc IBackingOracle
    // slither-disable-next-line naming-convention
    function MAX_STALENESS() external view override returns (uint256) {
        return maxStaleness;
    }

    /// @inheritdoc IBackingOracle
    // slither-disable-next-line naming-convention
    function MAX_DEVIATION() external view override returns (uint256) {
        return maxDeviation;
    }

    /**
     * @notice Returns the current backing amount from the Chainlink aggregator.
     * @dev This is a view function and cannot update previousAnswer for deviation tracking.
     *      Call refreshPreviousAnswer() periodically to keep deviation tracking accurate.
     *      Reads latestRoundData() and scales the answer to 18 decimals.
     * @return The backing amount in 18-decimal base units.
     */
    function getBackingAmount() external view override returns (uint256) {
        // slither-disable-next-line unused-return
        (, int256 answer,, uint256 updatedAt,) = aggregator.latestRoundData();
        if (answer <= 0) revert ZeroAnswer();
        // slither-disable-next-line timestamp
        if (block.timestamp - updatedAt > maxStaleness) {
            revert StaleData(updatedAt, maxStaleness);
        }

        return _scaleTo18(uint256(answer));
    }

    /**
     * @notice Refreshes the stored previous answer from the current feed.
     * @dev Call this after each significant read to keep deviation tracking
     *      up to date. Separated from getBackingAmount() because view
     *      functions cannot modify state.
     */
    function refreshPreviousAnswer() external {
        // slither-disable-next-line unused-return
        (, int256 answer,, uint256 updatedAt,) = aggregator.latestRoundData();
        if (answer <= 0) revert ZeroAnswer();

        uint256 scaled = _scaleTo18(uint256(answer));

        if (updatedAt > previousTimestamp) {
            if (previousAnswer > 0 && scaled != previousAnswer) {
                emit BackingUpdated(scaled, block.timestamp, msg.sender);
            }
            previousAnswer = scaled;
            previousTimestamp = updatedAt;
        }
    }

    /// @inheritdoc IBackingOracle
    function isHealthy() external view override returns (bool) {
        // slither-disable-next-line unused-return
        (, int256 answer,, uint256 updatedAt,) = aggregator.latestRoundData();

        // Must have a positive answer.
        if (answer <= 0) return false;

        // Must not be stale.
        // slither-disable-next-line timestamp
        if (block.timestamp - updatedAt > maxStaleness) return false;

        // Must be within deviation bounds.
        if (previousAnswer > 0) {
            uint256 scaled = _scaleTo18(uint256(answer));
            uint256 dev = _calculateDeviation(scaled, previousAnswer);
            if (dev > maxDeviation) return false;
        }

        return true;
    }

    /// @inheritdoc IBackingOracle
    function lastUpdate() external view override returns (uint256) {
        // slither-disable-next-line unused-return
        (,,,uint256 updatedAt,) = aggregator.latestRoundData();
        return updatedAt;
    }

    /// @inheritdoc IBackingOracle
    function deviation() external view override returns (uint256) {
        if (previousAnswer == 0) return 0;

        // slither-disable-next-line unused-return
        (, int256 answer,,, ) = aggregator.latestRoundData();
        if (answer <= 0) return type(uint256).max;

        uint256 scaled = _scaleTo18(uint256(answer));
        return _calculateDeviation(scaled, previousAnswer);
    }

    /// @inheritdoc IBackingOracle
    function sourceCount() external pure override returns (uint256) {
        return 1;
    }

    /// @inheritdoc IBackingOracle
    function confidence() external view override returns (uint256) {
        // slither-disable-next-line unused-return
        (, int256 answer,, uint256 updatedAt,) = aggregator.latestRoundData();

        if (answer <= 0) return 0;

        // Stale data gets reduced confidence.
        // slither-disable-next-line timestamp
        if (block.timestamp - updatedAt > maxStaleness) return 5000;

        return 10_000;
    }

    // -------------------------------------------------------------------
    //  External — Admin Configuration
    // -------------------------------------------------------------------

    /**
     * @notice Updates the staleness threshold.
     * @param newMaxStaleness The new maximum staleness in seconds.
     */
    function setMaxStaleness(uint256 newMaxStaleness) external onlyRole(ADMIN_ROLE) {
        maxStaleness = newMaxStaleness;
    }

    /**
     * @notice Updates the deviation threshold.
     * @param newMaxDeviation The new maximum deviation in basis points.
     */
    function setMaxDeviation(uint256 newMaxDeviation) external onlyRole(ADMIN_ROLE) {
        maxDeviation = newMaxDeviation;
    }

    // -------------------------------------------------------------------
    //  Internal
    // -------------------------------------------------------------------

    /**
     * @dev Scales a feed answer from `feedDecimals` to 18 decimals.
     * @param answer The raw answer from the aggregator.
     * @return The answer scaled to 18 decimals.
     */
    function _scaleTo18(uint256 answer) internal view returns (uint256) {
        if (feedDecimals < 18) {
            return answer * (10 ** (18 - feedDecimals));
        } else if (feedDecimals > 18) {
            return answer / (10 ** (feedDecimals - 18));
        }
        return answer;
    }

    /**
     * @dev Calculates the absolute deviation between two values in basis
     *      points: |a - b| * 10000 / b.
     * @param current  The current value.
     * @param previous The previous value (must be > 0).
     * @return The deviation in basis points.
     */
    function _calculateDeviation(
        uint256 current,
        uint256 previous
    ) internal pure returns (uint256) {
        if (previous == 0) return 0;

        uint256 diff = current > previous
            ? current - previous
            : previous - current;

        return (diff * 10_000) / previous;
    }
}
