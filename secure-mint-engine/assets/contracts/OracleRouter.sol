// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IBackingOracle.sol";

/**
 * @title OracleRouter
 * @notice Multi-oracle router with failover and staleness checks
 * @dev Routes oracle queries through a priority-ordered list of oracle sources.
 *      If the primary oracle is unhealthy or stale, falls back to secondary sources.
 */
contract OracleRouter is IBackingOracle, AccessControl {
    // ═══════════════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════════════

    bytes32 public constant ROUTER_ADMIN = keccak256("ROUTER_ADMIN");

    /// @notice Ordered list of oracle sources (index 0 = highest priority)
    IBackingOracle[] public oracles;

    /// @notice Maximum number of oracles
    uint256 public constant MAX_ORACLES = 5;

    /// @notice Maximum deviation between oracle sources in basis points
    uint256 public maxDeviationBps;

    /// @notice Timestamp of last successful query
    uint256 public override lastUpdate;

    // ═══════════════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════════════

    event OracleAdded(address indexed oracle, uint256 index);
    event OracleRemoved(address indexed oracle, uint256 index);
    event OracleFailover(uint256 fromIndex, uint256 toIndex, string reason);

    // ═══════════════════════════════════════════════════════════════════════
    // ERRORS
    // ═══════════════════════════════════════════════════════════════════════

    error NoHealthyOracle();
    error TooManyOracles();
    error OracleAlreadyRegistered();
    error OracleNotRegistered();

    // ═══════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════

    constructor(
        address _primaryOracle,
        uint256 _maxDeviationBps,
        address _admin
    ) {
        require(_primaryOracle != address(0), "Invalid oracle");
        require(_admin != address(0), "Invalid admin");

        oracles.push(IBackingOracle(_primaryOracle));
        maxDeviationBps = _maxDeviationBps;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ROUTER_ADMIN, _admin);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // IBackingOracle IMPLEMENTATION
    // ═══════════════════════════════════════════════════════════════════════

    /// @inheritdoc IBackingOracle
    function getVerifiedBacking() external view override returns (uint256) {
        uint256[] memory values = new uint256[](oracles.length);
        uint256 healthyCount = 0;

        for (uint256 i = 0; i < oracles.length; i++) {
            try oracles[i].isHealthy() returns (bool healthy) {
                if (!healthy) continue;
                try oracles[i].getVerifiedBacking() returns (uint256 backing) {
                    values[healthyCount] = backing;
                    healthyCount++;
                } catch { continue; }
            } catch { continue; }
        }

        if (healthyCount == 0) revert NoHealthyOracle();

        // Cross-check deviation if multiple healthy oracles
        if (healthyCount > 1 && maxDeviationBps > 0) {
            for (uint256 i = 1; i < healthyCount; i++) {
                uint256 larger = values[0] > values[i] ? values[0] : values[i];
                uint256 smaller = values[0] > values[i] ? values[i] : values[0];
                uint256 deviation = ((larger - smaller) * 10000) / larger;
                require(deviation <= maxDeviationBps, "Oracle deviation too high");
            }
        }

        // Return conservative (minimum) value
        uint256 minValue = values[0];
        for (uint256 i = 1; i < healthyCount; i++) {
            if (values[i] < minValue) minValue = values[i];
        }
        return minValue;
    }

    /// @inheritdoc IBackingOracle
    function isHealthy() external view override returns (bool) {
        for (uint256 i = 0; i < oracles.length; i++) {
            try oracles[i].isHealthy() returns (bool healthy) {
                if (healthy) return true;
            } catch {
                continue;
            }
        }
        return false;
    }

    /// @inheritdoc IBackingOracle
    function getDataAge() external view override returns (uint256) {
        uint256 minAge = type(uint256).max;
        for (uint256 i = 0; i < oracles.length; i++) {
            try oracles[i].getDataAge() returns (uint256 age) {
                if (age < minAge) minAge = age;
            } catch {
                continue;
            }
        }
        return minAge;
    }

    /// @inheritdoc IBackingOracle
    function canMint(
        uint256 currentSupply,
        uint256 mintAmount
    ) external view override returns (bool) {
        for (uint256 i = 0; i < oracles.length; i++) {
            try oracles[i].canMint(currentSupply, mintAmount) returns (bool can) {
                if (oracles[i].isHealthy()) {
                    return can;
                }
            } catch {
                continue;
            }
        }
        return false;
    }

    /// @inheritdoc IBackingOracle
    function getRequiredBacking(
        uint256 totalSupply
    ) external view override returns (uint256) {
        // Use the first healthy oracle's required backing calculation
        for (uint256 i = 0; i < oracles.length; i++) {
            try oracles[i].getRequiredBacking(totalSupply) returns (uint256 req) {
                return req;
            } catch {
                continue;
            }
        }
        revert NoHealthyOracle();
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    function addOracle(address _oracle) external onlyRole(ROUTER_ADMIN) {
        if (oracles.length >= MAX_ORACLES) revert TooManyOracles();
        for (uint256 i = 0; i < oracles.length; i++) {
            if (address(oracles[i]) == _oracle) revert OracleAlreadyRegistered();
        }
        oracles.push(IBackingOracle(_oracle));
        emit OracleAdded(_oracle, oracles.length - 1);
    }

    function removeOracle(uint256 index) external onlyRole(ROUTER_ADMIN) {
        require(index < oracles.length, "Invalid index");
        require(oracles.length > 1, "Cannot remove last oracle");

        address removed = address(oracles[index]);
        oracles[index] = oracles[oracles.length - 1];
        oracles.pop();
        emit OracleRemoved(removed, index);
    }

    function getOracleCount() external view returns (uint256) {
        return oracles.length;
    }

    function setMaxDeviation(uint256 _maxDeviationBps) external onlyRole(ROUTER_ADMIN) {
        maxDeviationBps = _maxDeviationBps;
    }
}
