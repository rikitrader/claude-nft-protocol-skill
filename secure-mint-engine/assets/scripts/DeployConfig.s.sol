// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";

/**
 * @title DeployConfig
 * @author SecureMintEngine
 * @notice Configuration library for SecureMintEngine deployment parameters.
 *         Provides per-network defaults and an environment-variable override path.
 */
library DeployConfig {
    // -------------------------------------------------------------------
    //  Structs
    // -------------------------------------------------------------------

    struct DeploymentConfig {
        // --- Token ---
        string tokenName;
        string tokenSymbol;
        uint8 tokenDecimals;
        // --- Mint Policy ---
        uint256 globalCap;
        uint256 epochCap;
        uint256 epochDuration;
        uint256 maxStaleness;
        uint256 maxDeviation;
        uint256 timelockDelay;
        // --- Emergency Pause ---
        uint256 fullFreezeTimelockDelay;
        uint256 cooldownPeriod;
        // --- Governance Timelock ---
        uint256 governanceTimelockMinDelay;
        // --- Governor ---
        uint256 governorQuorum;
        uint256 governorVotingPeriod;
        // --- GuardianMultisig ---
        uint256 guardianMultisigRequired;
        // --- Addresses (external dependencies) ---
        address admin;
        address oracleAggregator;
        address collateralToken;
        address guardian;
        address operator;
        address treasurer;
        address dao;
        address feeRecipient;
    }

    // -------------------------------------------------------------------
    //  Network Configurations
    // -------------------------------------------------------------------

    /**
     * @notice Returns a reasonable default configuration for the Sepolia testnet.
     * @dev Uses smaller caps and shorter delays to facilitate testing.
     * @return config The Sepolia deployment configuration.
     */
    function getSepoliaConfig() internal pure returns (DeploymentConfig memory config) {
        config = DeploymentConfig({
            // Token
            tokenName: "USD Backed Token",
            tokenSymbol: "USDX",
            tokenDecimals: 18,
            // Mint Policy
            globalCap: 10_000_000 ether, // 10M tokens
            epochCap: 1_000_000 ether, // 1M tokens per epoch
            epochDuration: 24 hours,
            maxStaleness: 3600, // 1 hour
            maxDeviation: 500, // 5% in basis points
            timelockDelay: 1 hours, // Short for testnet
            // Emergency Pause
            fullFreezeTimelockDelay: 2 hours, // Short for testnet
            cooldownPeriod: 30 minutes, // Short for testnet
            // Governance Timelock
            governanceTimelockMinDelay: 1 hours, // Short for testnet
            // Governor
            governorQuorum: 2, // 2 votes needed for testnet
            governorVotingPeriod: 50, // ~50 blocks for testnet
            // GuardianMultisig
            guardianMultisigRequired: 1, // 1-of-N for testnet
            // Addresses — must be overridden via env vars at deploy time
            admin: address(0),
            oracleAggregator: address(0),
            collateralToken: address(0),
            guardian: address(0),
            operator: address(0),
            treasurer: address(0),
            dao: address(0),
            feeRecipient: address(0)
        });
    }

    /**
     * @notice Returns a production-grade configuration for Ethereum mainnet.
     * @dev Uses conservative caps and longer timelocks for security.
     * @return config The mainnet deployment configuration.
     */
    function getMainnetConfig() internal pure returns (DeploymentConfig memory config) {
        config = DeploymentConfig({
            // Token
            tokenName: "USD Backed Token",
            tokenSymbol: "USDX",
            tokenDecimals: 18,
            // Mint Policy
            globalCap: 1_000_000_000 ether, // 1B tokens
            epochCap: 10_000_000 ether, // 10M tokens per epoch
            epochDuration: 24 hours,
            maxStaleness: 3600, // 1 hour
            maxDeviation: 500, // 5% in basis points
            timelockDelay: 48 hours, // 2 days for config changes
            // Emergency Pause
            fullFreezeTimelockDelay: 7 days, // 7 days to lift full freeze
            cooldownPeriod: 6 hours, // 6 hours between de-escalations
            // Governance Timelock
            governanceTimelockMinDelay: 48 hours, // 2 days
            // Governor
            governorQuorum: 5, // 5 votes needed for mainnet
            governorVotingPeriod: 50400, // ~7 days (12s blocks)
            // GuardianMultisig
            guardianMultisigRequired: 3, // 3-of-N for mainnet
            // Addresses — must be overridden via env vars at deploy time
            admin: address(0),
            oracleAggregator: address(0),
            collateralToken: address(0),
            guardian: address(0),
            operator: address(0),
            treasurer: address(0),
            dao: address(0),
            feeRecipient: address(0)
        });
    }

    /**
     * @notice Reads deployment configuration from environment variables.
     * @dev All address fields are REQUIRED (will revert if zero).
     *      Numeric fields fall back to Sepolia defaults if the env var is not set.
     * @param vm The Vm interface from forge-std for reading env vars.
     * @return config The deployment configuration populated from the environment.
     */
    function getConfigFromEnv(Vm vm) internal view returns (DeploymentConfig memory config) {
        // Start from Sepolia defaults for numeric fields
        config = getSepoliaConfig();

        // --- Required addresses ---
        config.admin = vm.envAddress("DEPLOY_ADMIN");
        config.oracleAggregator = vm.envAddress("DEPLOY_ORACLE_AGGREGATOR");
        config.collateralToken = vm.envAddress("DEPLOY_COLLATERAL_TOKEN");
        config.guardian = vm.envAddress("DEPLOY_GUARDIAN");
        config.operator = vm.envAddress("DEPLOY_OPERATOR");
        config.treasurer = vm.envAddress("DEPLOY_TREASURER");
        config.dao = vm.envAddress("DEPLOY_DAO");
        config.feeRecipient = vm.envAddress("DEPLOY_FEE_RECIPIENT");

        // --- Optional overrides (use env var if set, otherwise keep default) ---
        config.tokenName = vm.envOr("DEPLOY_TOKEN_NAME", config.tokenName);
        config.tokenSymbol = vm.envOr("DEPLOY_TOKEN_SYMBOL", config.tokenSymbol);
        config.tokenDecimals = uint8(vm.envOr("DEPLOY_TOKEN_DECIMALS", uint256(config.tokenDecimals)));

        config.globalCap = vm.envOr("DEPLOY_GLOBAL_CAP", config.globalCap);
        config.epochCap = vm.envOr("DEPLOY_EPOCH_CAP", config.epochCap);
        config.epochDuration = vm.envOr("DEPLOY_EPOCH_DURATION", config.epochDuration);
        config.maxStaleness = vm.envOr("DEPLOY_MAX_STALENESS", config.maxStaleness);
        config.maxDeviation = vm.envOr("DEPLOY_MAX_DEVIATION", config.maxDeviation);
        config.timelockDelay = vm.envOr("DEPLOY_TIMELOCK_DELAY", config.timelockDelay);

        config.fullFreezeTimelockDelay = vm.envOr("DEPLOY_FULL_FREEZE_TIMELOCK_DELAY", config.fullFreezeTimelockDelay);
        config.cooldownPeriod = vm.envOr("DEPLOY_COOLDOWN_PERIOD", config.cooldownPeriod);

        config.governanceTimelockMinDelay =
            vm.envOr("DEPLOY_GOVERNANCE_TIMELOCK_MIN_DELAY", config.governanceTimelockMinDelay);

        config.governorQuorum = vm.envOr("DEPLOY_GOVERNOR_QUORUM", config.governorQuorum);
        config.governorVotingPeriod = vm.envOr("DEPLOY_GOVERNOR_VOTING_PERIOD", config.governorVotingPeriod);

        config.guardianMultisigRequired =
            vm.envOr("DEPLOY_GUARDIAN_MULTISIG_REQUIRED", config.guardianMultisigRequired);
    }
}
