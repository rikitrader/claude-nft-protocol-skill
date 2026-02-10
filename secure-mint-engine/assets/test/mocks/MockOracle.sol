// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MockBackingOracle.sol";

/**
 * @title IAggregatorV3
 * @notice Chainlink AggregatorV3Interface for oracle price feeds
 * @dev Minimal interface matching Chainlink's AggregatorV3Interface
 */
interface IAggregatorV3 {
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function version() external view returns (uint256);

    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

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
}

/**
 * @title MockOracle
 * @notice Configurable mock oracle wrapping MockBackingOracle with Chainlink-style latestRoundData()
 * @dev Combines backing oracle functionality with a Chainlink-compatible price feed interface.
 *      All responses are fully configurable for comprehensive edge-case testing:
 *      - Price feed (latestRoundData, getRoundData)
 *      - Backing oracle (verified backing, health, staleness)
 *      - Round management (round IDs, stale rounds)
 *      - Error conditions (zero price, negative price, stale timestamp)
 */
contract MockOracle is IAggregatorV3 {
    // ═══════════════════════════════════════════════════════════════════════════
    // BACKING ORACLE (COMPOSITION)
    // ═══════════════════════════════════════════════════════════════════════════

    MockBackingOracle public backingOracle;

    // ═══════════════════════════════════════════════════════════════════════════
    // CHAINLINK-STYLE STATE
    // ═══════════════════════════════════════════════════════════════════════════

    uint8 private _decimals;
    string private _description;

    int256 private _latestAnswer;
    uint256 private _startedAt;
    uint256 private _updatedAt;
    uint80 private _latestRoundId;

    /// @notice Whether latestRoundData should revert (simulates feed failure)
    bool public shouldRevert;
    string public revertReason;

    /// @notice Historical round data for getRoundData
    struct RoundData {
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
        bool exists;
    }
    mapping(uint80 => RoundData) private _roundData;

    // ═══════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════════════════

    event PriceUpdated(int256 newPrice, uint80 roundId, uint256 timestamp);
    event HealthStatusChanged(bool healthy);

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Deploy MockOracle with sensible defaults
     * @param decimals_ Price feed decimals (typically 8 for USD feeds)
     * @param initialPrice Initial price answer (e.g., 1e8 for $1.00)
     */
    constructor(uint8 decimals_, int256 initialPrice) {
        backingOracle = new MockBackingOracle();

        _decimals = decimals_;
        _description = "MockOracle / USD";
        _latestAnswer = initialPrice;
        _startedAt = block.timestamp;
        _updatedAt = block.timestamp;
        _latestRoundId = 1;

        // Store initial round
        _roundData[1] = RoundData({
            answer: initialPrice,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 1,
            exists: true
        });
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // IAggregatorV3 INTERFACE
    // ═══════════════════════════════════════════════════════════════════════════

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function description() external view override returns (string memory) {
        return _description;
    }

    function version() external pure override returns (uint256) {
        return 4;
    }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        if (shouldRevert) {
            revert(revertReason);
        }

        return (
            _latestRoundId,
            _latestAnswer,
            _startedAt,
            _updatedAt,
            _latestRoundId
        );
    }

    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        if (shouldRevert) {
            revert(revertReason);
        }

        RoundData memory data = _roundData[_roundId];
        if (!data.exists) {
            // Return the latest data for non-existent rounds (Chainlink behavior)
            return (
                _roundId,
                _latestAnswer,
                _startedAt,
                _updatedAt,
                _roundId
            );
        }

        return (
            _roundId,
            data.answer,
            data.startedAt,
            data.updatedAt,
            data.answeredInRound
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CHAINLINK SETTERS (for testing)
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Set the latest price answer and advance the round
     * @param answer New price answer
     */
    function setLatestAnswer(int256 answer) external {
        _latestRoundId++;
        _latestAnswer = answer;
        _updatedAt = block.timestamp;
        _startedAt = block.timestamp;

        _roundData[_latestRoundId] = RoundData({
            answer: answer,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: _latestRoundId,
            exists: true
        });

        emit PriceUpdated(answer, _latestRoundId, block.timestamp);
    }

    /**
     * @notice Set the updatedAt timestamp (for staleness testing)
     * @param timestamp The timestamp to set
     */
    function setUpdatedAt(uint256 timestamp) external {
        _updatedAt = timestamp;
    }

    /**
     * @notice Set the startedAt timestamp
     * @param timestamp The timestamp to set
     */
    function setStartedAt(uint256 timestamp) external {
        _startedAt = timestamp;
    }

    /**
     * @notice Set the latest round ID directly
     * @param roundId The round ID to set
     */
    function setLatestRoundId(uint80 roundId) external {
        _latestRoundId = roundId;
    }

    /**
     * @notice Set a specific round's data
     * @param roundId Round ID
     * @param answer Price answer
     * @param startedAt Started timestamp
     * @param updatedAt Updated timestamp
     * @param answeredInRound The round in which the answer was computed
     */
    function setRoundData(
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) external {
        _roundData[roundId] = RoundData({
            answer: answer,
            startedAt: startedAt,
            updatedAt: updatedAt,
            answeredInRound: answeredInRound,
            exists: true
        });
    }

    /**
     * @notice Set the description string
     * @param desc New description
     */
    function setDescription(string calldata desc) external {
        _description = desc;
    }

    /**
     * @notice Set the decimals value
     * @param decimals_ New decimals
     */
    function setDecimals(uint8 decimals_) external {
        _decimals = decimals_;
    }

    /**
     * @notice Configure latestRoundData to revert (simulates feed outage)
     * @param _shouldRevert Whether to revert
     * @param _reason Revert reason string
     */
    function setShouldRevert(bool _shouldRevert, string calldata _reason) external {
        shouldRevert = _shouldRevert;
        revertReason = _reason;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // BACKING ORACLE DELEGATED SETTERS
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Set verified backing amount via the inner backing oracle
     * @param backing New backing amount
     */
    function setVerifiedBacking(uint256 backing) external {
        backingOracle.setVerifiedBacking(backing);
    }

    /**
     * @notice Set health status via the inner backing oracle
     * @param healthy New health status
     */
    function setHealthy(bool healthy) external {
        backingOracle.setHealthy(healthy);
        emit HealthStatusChanged(healthy);
    }

    /**
     * @notice Set canMint response via the inner backing oracle
     * @param canMint_ New canMint result
     */
    function setCanMint(bool canMint_) external {
        backingOracle.setCanMint(canMint_);
    }

    /**
     * @notice Set depegged status via the inner backing oracle
     * @param depegged_ New depeg status
     */
    function setDepegged(bool depegged_) external {
        backingOracle.setDepegged(depegged_);
    }

    /**
     * @notice Set depeg surcharge rate via the inner backing oracle
     * @param rate New surcharge rate
     */
    function setDepegSurchargeRate(uint256 rate) external {
        backingOracle.setDepegSurchargeRate(rate);
    }

    /**
     * @notice Update the backing oracle's timestamp to now
     */
    function refreshBackingOracleTimestamp() external {
        backingOracle.updateTimestamp();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // BACKING ORACLE DELEGATED VIEWS
    // ═══════════════════════════════════════════════════════════════════════════

    function getVerifiedBacking() external view returns (uint256) {
        return backingOracle.getVerifiedBacking();
    }

    function isHealthy() external view returns (bool) {
        return backingOracle.isHealthy();
    }

    function getDataAge() external view returns (uint256) {
        return backingOracle.getDataAge();
    }

    function canMint(uint256 currentSupply, uint256 mintAmount) external view returns (bool) {
        return backingOracle.canMint(currentSupply, mintAmount);
    }

    function isDepegged() external view returns (bool) {
        return backingOracle.isDepegged();
    }

    function getPrice() external view returns (int256) {
        return _latestAnswer;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONVENIENCE HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Set up a "stale feed" scenario: answer is old, but price is valid
     * @param secondsStale How many seconds in the past the updatedAt should be
     */
    function simulateStaleFeed(uint256 secondsStale) external {
        _updatedAt = block.timestamp - secondsStale;
    }

    /**
     * @notice Set up a "zero price" scenario
     */
    function simulateZeroPrice() external {
        _latestAnswer = 0;
    }

    /**
     * @notice Set up a "negative price" scenario
     */
    function simulateNegativePrice() external {
        _latestAnswer = -1;
    }

    /**
     * @notice Set up an "incomplete round" scenario (answeredInRound < roundId)
     */
    function simulateIncompleteRound() external {
        _latestRoundId++;
        _roundData[_latestRoundId] = RoundData({
            answer: _latestAnswer,
            startedAt: block.timestamp,
            updatedAt: 0,
            answeredInRound: _latestRoundId - 1, // Incomplete
            exists: true
        });
    }
}
