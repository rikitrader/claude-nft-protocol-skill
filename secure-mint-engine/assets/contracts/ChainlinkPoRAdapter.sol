// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IBackingOracle.sol";

/**
 * @title ChainlinkPoRAdapter
 * @notice Adapter for Chainlink Proof-of-Reserve feeds
 * @dev Wraps Chainlink's AggregatorV3Interface for use with SecureMintPolicy.
 *      Provides staleness checks, deviation bounds, and health reporting.
 */
contract ChainlinkPoRAdapter is IBackingOracle, AccessControl {
    // ═══════════════════════════════════════════════════════════════════════
    // TYPES
    // ═══════════════════════════════════════════════════════════════════════

    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");

    /// @notice Chainlink Aggregator interface (minimal)
    interface IAggregatorV3 {
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

    // ═══════════════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Primary Chainlink PoR feed
    IAggregatorV3 public primaryFeed;

    /// @notice Fallback feed (optional)
    IAggregatorV3 public fallbackFeed;

    /// @notice Maximum acceptable data age in seconds
    uint256 public maxStaleness;

    /// @notice Maximum deviation between feeds in basis points
    uint256 public maxDeviationBps;

    /// @notice Minimum collateral ratio in basis points (10000 = 100%)
    uint256 public minCollateralRatio;

    /// @notice Timestamp of last successful update
    uint256 public override lastUpdate;

    // ═══════════════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════════════

    event FeedUpdated(address indexed newFeed, bool isPrimary);
    event StalenessUpdated(uint256 oldValue, uint256 newValue);
    event DeviationUpdated(uint256 oldValue, uint256 newValue);

    // ═══════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════

    constructor(
        address _primaryFeed,
        uint256 _maxStaleness,
        uint256 _maxDeviationBps,
        uint256 _minCollateralRatio,
        address _admin
    ) {
        require(_primaryFeed != address(0), "Invalid feed");
        require(_admin != address(0), "Invalid admin");

        primaryFeed = IAggregatorV3(_primaryFeed);
        maxStaleness = _maxStaleness;
        maxDeviationBps = _maxDeviationBps;
        minCollateralRatio = _minCollateralRatio;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPDATER_ROLE, _admin);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // IBackingOracle IMPLEMENTATION
    // ═══════════════════════════════════════════════════════════════════════

    /// @inheritdoc IBackingOracle
    function getVerifiedBacking() external view override returns (uint256) {
        (, int256 answer, , uint256 updatedAt, ) = primaryFeed.latestRoundData();
        require(answer > 0, "Invalid PoR data");
        require(block.timestamp - updatedAt <= maxStaleness, "PoR data stale");

        return uint256(answer);
    }

    /// @inheritdoc IBackingOracle
    function isHealthy() external view override returns (bool) {
        try primaryFeed.latestRoundData() returns (
            uint80, int256 answer, uint256, uint256 updatedAt, uint80
        ) {
            if (answer <= 0) return false;
            if (block.timestamp - updatedAt > maxStaleness) return false;

            // Check fallback deviation if available
            if (address(fallbackFeed) != address(0)) {
                try fallbackFeed.latestRoundData() returns (
                    uint80, int256 fallbackAnswer, uint256, uint256, uint80
                ) {
                    if (fallbackAnswer > 0) {
                        uint256 deviation = _calculateDeviation(
                            uint256(answer),
                            uint256(fallbackAnswer)
                        );
                        if (deviation > maxDeviationBps) return false;
                    }
                } catch {
                    // Fallback failure is acceptable if primary is healthy
                }
            }

            return true;
        } catch {
            return false;
        }
    }

    /// @inheritdoc IBackingOracle
    function getDataAge() external view override returns (uint256) {
        (, , , uint256 updatedAt, ) = primaryFeed.latestRoundData();
        return block.timestamp - updatedAt;
    }

    /// @inheritdoc IBackingOracle
    function canMint(
        uint256 currentSupply,
        uint256 mintAmount
    ) external view override returns (bool) {
        try primaryFeed.latestRoundData() returns (
            uint80, int256 answer, uint256, uint256 updatedAt, uint80
        ) {
            if (answer <= 0) return false;
            if (block.timestamp - updatedAt > maxStaleness) return false;

            uint256 backing = uint256(answer);
            uint256 postMintSupply = currentSupply + mintAmount;
            uint256 requiredBacking = (postMintSupply * minCollateralRatio) / 10000;

            return backing >= requiredBacking;
        } catch {
            return false;
        }
    }

    /// @inheritdoc IBackingOracle
    function getRequiredBacking(
        uint256 totalSupply
    ) external view override returns (uint256) {
        return (totalSupply * minCollateralRatio) / 10000;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    function setFallbackFeed(address _feed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        fallbackFeed = IAggregatorV3(_feed);
        emit FeedUpdated(_feed, false);
    }

    function setMaxStaleness(uint256 _maxStaleness) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emit StalenessUpdated(maxStaleness, _maxStaleness);
        maxStaleness = _maxStaleness;
    }

    function setMaxDeviation(uint256 _maxDeviationBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emit DeviationUpdated(maxDeviationBps, _maxDeviationBps);
        maxDeviationBps = _maxDeviationBps;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // INTERNAL
    // ═══════════════════════════════════════════════════════════════════════

    function _calculateDeviation(
        uint256 a,
        uint256 b
    ) internal pure returns (uint256) {
        if (a == 0 && b == 0) return 0;
        uint256 diff = a > b ? a - b : b - a;
        uint256 avg = (a + b) / 2;
        return (diff * 10000) / avg;
    }
}
