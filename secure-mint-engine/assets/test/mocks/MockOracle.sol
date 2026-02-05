// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../contracts/IBackingOracle.sol";

/**
 * @title MockOracle
 * @notice A configurable mock implementation of IBackingOracle for testing.
 * @dev All return values are freely settable to simulate any oracle state:
 *      healthy, stale, deviating, under-backed, etc.
 */
contract MockOracle is IBackingOracle {
    // -------------------------------------------------------------------
    //  Configurable State
    // -------------------------------------------------------------------

    uint256 private _backingAmount;
    bool private _healthy;
    uint256 private _lastUpdate;
    uint256 private _deviation;
    uint256 private _sourceCount;
    uint256 private _confidence;
    uint256 private _maxStaleness;
    uint256 private _maxDeviation;

    // -------------------------------------------------------------------
    //  Constructor
    // -------------------------------------------------------------------

    constructor() {
        _backingAmount = 1e24; // 1M tokens worth of backing (18 decimals)
        _healthy = true;
        _lastUpdate = block.timestamp;
        _deviation = 0;
        _sourceCount = 3;
        _confidence = 10_000; // 100%
        _maxStaleness = 3600; // 1 hour
        _maxDeviation = 500; // 5%
    }

    // -------------------------------------------------------------------
    //  Setters (test helpers)
    // -------------------------------------------------------------------

    function setBackingAmount(uint256 amount) external {
        _backingAmount = amount;
    }

    function setHealthy(bool healthy) external {
        _healthy = healthy;
    }

    function setLastUpdate(uint256 timestamp) external {
        _lastUpdate = timestamp;
    }

    function setDeviation(uint256 dev) external {
        _deviation = dev;
    }

    function setSourceCount(uint256 count) external {
        _sourceCount = count;
    }

    function setConfidence(uint256 conf) external {
        _confidence = conf;
    }

    function setMaxStaleness(uint256 staleness) external {
        _maxStaleness = staleness;
    }

    function setMaxDeviation(uint256 dev) external {
        _maxDeviation = dev;
    }

    // -------------------------------------------------------------------
    //  IBackingOracle Implementation
    // -------------------------------------------------------------------

    function MAX_STALENESS() external view override returns (uint256) {
        return _maxStaleness;
    }

    function MAX_DEVIATION() external view override returns (uint256) {
        return _maxDeviation;
    }

    function getBackingAmount() external view override returns (uint256) {
        return _backingAmount;
    }

    function isHealthy() external view override returns (bool) {
        return _healthy;
    }

    function lastUpdate() external view override returns (uint256) {
        return _lastUpdate;
    }

    function deviation() external view override returns (uint256) {
        return _deviation;
    }

    function sourceCount() external view override returns (uint256) {
        return _sourceCount;
    }

    function confidence() external view override returns (uint256) {
        return _confidence;
    }
}
