// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

/**
 * @title DeployConfig
 * @notice Chain-specific deployment configuration library for SecureMintEngine
 * @dev Provides deterministic parameters for each supported chain.
 *      All addresses, names, and limits are centralised here to avoid
 *      hard-coding across individual deployment scripts.
 *
 * SUPPORTED CHAINS:
 * - Ethereum Mainnet  (chainId = 1)
 * - Holesky Testnet   (chainId = 17000)
 * - Sepolia Testnet   (chainId = 11155111)
 * - Polygon PoS       (chainId = 137)
 * - Arbitrum One      (chainId = 42161)
 */
library DeployConfig {
    // ═══════════════════════════════════════════════════════════════════════════
    // TYPES
    // ═══════════════════════════════════════════════════════════════════════════

    struct ChainConfig {
        // ── Token Metadata ──────────────────────────────────────────────────
        string tokenName;
        string tokenSymbol;
        // ── Oracle ──────────────────────────────────────────────────────────
        address chainlinkPoRFeed;
        uint256 maxOracleAge;
        uint256 maxDeviationBps;
        uint256 minCollateralRatio;
        // ── Supply Limits ───────────────────────────────────────────────────
        uint256 globalSupplyCap;
        uint256 epochMintCap;
        uint256 epochDuration;
        // ── Redemption Limits ───────────────────────────────────────────────
        uint256 epochRedemptionCap;
        uint256 minRedemption;
        uint256 maxInstantRedemption;
        // ── Treasury ────────────────────────────────────────────────────────
        address reserveAsset;
        address treasury;
        uint256[4] tierAllocations;
        // ── Governance ──────────────────────────────────────────────────────
        address admin;
        address guardian;
        uint256 timelockDelay;
        uint48 votingDelay;
        uint32 votingPeriod;
        uint256 proposalThreshold;
        uint256 quorumPercentage;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ═══════════════════════════════════════════════════════════════════════════

    error UnsupportedChain(uint256 chainId);

    // ═══════════════════════════════════════════════════════════════════════════
    // PUBLIC API
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Return the full deployment configuration for the given chain.
     * @param chainId The EIP-155 chain identifier.
     * @return config The populated ChainConfig struct.
     */
    function getConfig(uint256 chainId) internal pure returns (ChainConfig memory config) {
        if (chainId == 1) {
            config = _mainnet();
        } else if (chainId == 17000) {
            config = _holesky();
        } else if (chainId == 11155111) {
            config = _sepolia();
        } else if (chainId == 137) {
            config = _polygon();
        } else if (chainId == 42161) {
            config = _arbitrum();
        } else {
            revert UnsupportedChain(chainId);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CHAIN CONFIGURATIONS (INTERNAL)
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @dev Ethereum Mainnet configuration.
     *      Production-grade limits with conservative oracle thresholds.
     */
    function _mainnet() private pure returns (ChainConfig memory) {
        return ChainConfig({
            // Token
            tokenName: "Backed USD",
            tokenSymbol: "bUSD",
            // Oracle – Chainlink PoR (USDC reserves)
            chainlinkPoRFeed: 0x390B163B79924dC685AD013e4fB0A06Ec4031423,
            maxOracleAge: 3600, // 1 hour
            maxDeviationBps: 200, // 2 %
            minCollateralRatio: 10_200, // 102 %
            // Supply
            globalSupplyCap: 1_000_000_000e18, // 1 B tokens
            epochMintCap: 10_000_000e18, // 10 M per epoch
            epochDuration: 3600, // 1 hour
            // Redemption
            epochRedemptionCap: 20_000_000e6, // 20 M USDC per epoch
            minRedemption: 1e6, // $1
            maxInstantRedemption: 100_000e6, // $100 k
            // Treasury – USDC on Mainnet
            reserveAsset: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            treasury: address(0), // Set at deploy time or via env
            tierAllocations: [uint256(750), 2000, 5500, 1750], // 7.5 / 20 / 55 / 17.5
            // Governance (placeholder – override with env at deploy time)
            admin: address(0),
            guardian: address(0),
            timelockDelay: 48 hours,
            votingDelay: 7200, // ~1 day in blocks (12 s block)
            votingPeriod: 36_000, // ~5 days
            proposalThreshold: 10_000_000e18, // 1 % of 1 B cap
            quorumPercentage: 4 // 4 %
        });
    }

    /**
     * @dev Holesky testnet configuration.
     *      Relaxed limits for integration testing.
     */
    function _holesky() private pure returns (ChainConfig memory) {
        return ChainConfig({
            tokenName: "Backed USD (Holesky)",
            tokenSymbol: "bUSD",
            chainlinkPoRFeed: address(0), // No PoR feed on Holesky – use mock
            maxOracleAge: 7200, // 2 hours (relaxed)
            maxDeviationBps: 500, // 5 %
            minCollateralRatio: 10_000, // 100 %
            globalSupplyCap: 100_000_000e18, // 100 M
            epochMintCap: 5_000_000e18, // 5 M
            epochDuration: 3600,
            epochRedemptionCap: 10_000_000e6,
            minRedemption: 1e6,
            maxInstantRedemption: 50_000e6,
            reserveAsset: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238, // USDC on Holesky
            treasury: address(0),
            tierAllocations: [uint256(1000), 2000, 5000, 2000],
            admin: address(0),
            guardian: address(0),
            timelockDelay: 1 hours, // short for testing
            votingDelay: 1, // 1 block
            votingPeriod: 50, // ~10 min
            proposalThreshold: 1e18,
            quorumPercentage: 1
        });
    }

    /**
     * @dev Sepolia testnet configuration.
     *      Relaxed limits for integration testing.
     */
    function _sepolia() private pure returns (ChainConfig memory) {
        return ChainConfig({
            tokenName: "Backed USD (Sepolia)",
            tokenSymbol: "bUSD",
            chainlinkPoRFeed: address(0), // Use mock
            maxOracleAge: 7200,
            maxDeviationBps: 500,
            minCollateralRatio: 10_000,
            globalSupplyCap: 100_000_000e18,
            epochMintCap: 5_000_000e18,
            epochDuration: 3600,
            epochRedemptionCap: 10_000_000e6,
            minRedemption: 1e6,
            maxInstantRedemption: 50_000e6,
            reserveAsset: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238, // USDC Sepolia
            treasury: address(0),
            tierAllocations: [uint256(1000), 2000, 5000, 2000],
            admin: address(0),
            guardian: address(0),
            timelockDelay: 1 hours,
            votingDelay: 1,
            votingPeriod: 50,
            proposalThreshold: 1e18,
            quorumPercentage: 1
        });
    }

    /**
     * @dev Polygon PoS configuration.
     *      Slightly lower caps; faster block times affect voting params.
     */
    function _polygon() private pure returns (ChainConfig memory) {
        return ChainConfig({
            tokenName: "Backed USD",
            tokenSymbol: "bUSD",
            chainlinkPoRFeed: address(0), // Deploy a ChainlinkPoRAdapter per-chain
            maxOracleAge: 3600,
            maxDeviationBps: 300, // 3 %
            minCollateralRatio: 10_100, // 101 %
            globalSupplyCap: 500_000_000e18, // 500 M
            epochMintCap: 5_000_000e18,
            epochDuration: 3600,
            epochRedemptionCap: 10_000_000e6,
            minRedemption: 1e6,
            maxInstantRedemption: 100_000e6,
            reserveAsset: 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359, // USDC native on Polygon
            treasury: address(0),
            tierAllocations: [uint256(1000), 2000, 5500, 1500],
            admin: address(0),
            guardian: address(0),
            timelockDelay: 48 hours,
            votingDelay: 21_600, // ~1 day @ 2 s blocks
            votingPeriod: 108_000, // ~5 days @ 2 s blocks
            proposalThreshold: 5_000_000e18,
            quorumPercentage: 4
        });
    }

    /**
     * @dev Arbitrum One configuration.
     *      L2-optimised with faster finality assumptions.
     */
    function _arbitrum() private pure returns (ChainConfig memory) {
        return ChainConfig({
            tokenName: "Backed USD",
            tokenSymbol: "bUSD",
            chainlinkPoRFeed: address(0),
            maxOracleAge: 3600,
            maxDeviationBps: 300,
            minCollateralRatio: 10_100,
            globalSupplyCap: 500_000_000e18,
            epochMintCap: 5_000_000e18,
            epochDuration: 3600,
            epochRedemptionCap: 10_000_000e6,
            minRedemption: 1e6,
            maxInstantRedemption: 100_000e6,
            reserveAsset: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831, // USDC native on Arbitrum
            treasury: address(0),
            tierAllocations: [uint256(1000), 2000, 5500, 1500],
            admin: address(0),
            guardian: address(0),
            timelockDelay: 48 hours,
            votingDelay: 21_600,
            votingPeriod: 108_000,
            proposalThreshold: 5_000_000e18,
            quorumPercentage: 4
        });
    }
}
