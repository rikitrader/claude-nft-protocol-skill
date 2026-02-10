// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "./DeployConfig.s.sol";

import "../contracts/BackedToken.sol";
import "../contracts/EmergencyPause.sol";
import "../contracts/TreasuryVault.sol";
import "../contracts/OracleRouter.sol";
import "../contracts/ChainlinkPoRAdapter.sol";
import "../contracts/SecureMintPolicy.sol";
import "../contracts/RedemptionEngine.sol";
import "../contracts/Governor.sol";
import "../contracts/Timelock.sol";

/**
 * @title Deploy
 * @notice Full 6-step Foundry deployment script for the SecureMintEngine protocol
 * @dev Deploys all core contracts and wires up AccessControl roles.
 *
 * DEPLOYMENT ORDER:
 *   1. BackedToken        – ERC-20 dumb ledger
 *   2. EmergencyPause     – 4-level circuit breaker
 *   3. TreasuryVault      – 4-tier reserve management
 *   4. OracleRouter / ChainlinkPoRAdapter – oracle infrastructure
 *   5. SecureMintPolicy   – oracle-gated mint controller
 *   6. RedemptionEngine + Governor + Timelock – redemption & governance
 *
 * ROLE WIRING:
 *   - MINTER_ROLE on SecureMintPolicy  -> granted to authorised minter (env)
 *   - GUARDIAN_ROLE on all contracts    -> guardian multisig
 *   - GOVERNOR_ROLE on policy/treasury  -> timelock (governance-controlled)
 *   - SecureMintPolicy address is set as the sole mint authority on BackedToken
 *
 * USAGE:
 *   forge script scripts/Deploy.s.sol:Deploy \
 *       --rpc-url $RPC_URL \
 *       --broadcast \
 *       --verify \
 *       -vvv
 *
 * ENVIRONMENT VARIABLES (override config defaults):
 *   DEPLOYER_PRIVATE_KEY  – private key of the deployer EOA
 *   ADMIN_ADDRESS         – protocol admin (multisig recommended)
 *   GUARDIAN_ADDRESS       – guardian address (multisig recommended)
 *   MINTER_ADDRESS        – address granted MINTER_ROLE on policy
 *   RESERVE_ASSET         – reserve asset override (e.g. USDC address)
 */
contract Deploy is Script {
    // ═══════════════════════════════════════════════════════════════════════════
    // DEPLOYED ADDRESSES
    // ═══════════════════════════════════════════════════════════════════════════

    BackedToken public backedToken;
    EmergencyPause public emergencyPause;
    TreasuryVault public treasuryVault;
    OracleRouter public oracleRouter;
    ChainlinkPoRAdapter public chainlinkAdapter;
    SecureMintPolicy public secureMintPolicy;
    RedemptionEngine public redemptionEngine;
    SecureMintGovernor public governor;
    Timelock public timelock;

    // ═══════════════════════════════════════════════════════════════════════════
    // MAIN ENTRY POINT
    // ═══════════════════════════════════════════════════════════════════════════

    function run() external {
        // ── Load configuration ──────────────────────────────────────────────
        DeployConfig.ChainConfig memory cfg = DeployConfig.getConfig(block.chainid);

        // ── Environment overrides ───────────────────────────────────────────
        address admin = _envOrDefault("ADMIN_ADDRESS", cfg.admin);
        address guardian = _envOrDefault("GUARDIAN_ADDRESS", cfg.guardian);
        address minter = _envOr("MINTER_ADDRESS", admin);
        address reserveAsset = _envOrDefault("RESERVE_ASSET", cfg.reserveAsset);

        require(admin != address(0), "Deploy: admin address required");
        require(guardian != address(0), "Deploy: guardian address required");
        require(reserveAsset != address(0), "Deploy: reserve asset required");

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // ── Step 1: Deploy EmergencyPause ───────────────────────────────────
        _step1_deployEmergencyPause(admin);

        // ── Step 2: Deploy TreasuryVault ────────────────────────────────────
        _step2_deployTreasuryVault(reserveAsset, admin, cfg.tierAllocations);

        // ── Step 3: Deploy Oracle Infrastructure ────────────────────────────
        _step3_deployOracle(cfg, admin);

        // ── Step 4: Deploy SecureMintPolicy ─────────────────────────────────
        // NOTE: BackedToken requires the policy address at construction, so
        // we deploy the policy first with a placeholder token, then deploy
        // the token. The policy's token reference is immutable, so we use
        // CREATE2 prediction or deploy the policy first and then the token.
        // In this script we deploy policy then token using predicted address.
        address oracleAddress = address(oracleRouter) != address(0)
            ? address(oracleRouter)
            : address(chainlinkAdapter);

        _step4_deploySecureMintPolicy(
            oracleAddress,
            cfg.globalSupplyCap,
            cfg.epochMintCap,
            cfg.maxOracleAge,
            admin
        );

        // ── Step 5: Deploy BackedToken ──────────────────────────────────────
        _step5_deployBackedToken(cfg.tokenName, cfg.tokenSymbol, guardian);

        // ── Step 6: Deploy Redemption + Governance ──────────────────────────
        _step6_deployRedemptionAndGovernance(
            reserveAsset,
            admin,
            guardian,
            cfg
        );

        // ── Wire up roles ───────────────────────────────────────────────────
        _wireRoles(admin, guardian, minter);

        vm.stopBroadcast();

        // ── Log deployed addresses ──────────────────────────────────────────
        _logDeployment();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STEP 1: EMERGENCY PAUSE
    // ═══════════════════════════════════════════════════════════════════════════

    function _step1_deployEmergencyPause(address admin) internal {
        emergencyPause = new EmergencyPause(admin);
        console.log("Step 1 - EmergencyPause deployed at:", address(emergencyPause));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STEP 2: TREASURY VAULT
    // ═══════════════════════════════════════════════════════════════════════════

    function _step2_deployTreasuryVault(
        address reserveAsset,
        address admin,
        uint256[4] memory tierAllocations
    ) internal {
        treasuryVault = new TreasuryVault(reserveAsset, admin, tierAllocations);
        console.log("Step 2 - TreasuryVault deployed at:", address(treasuryVault));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STEP 3: ORACLE INFRASTRUCTURE
    // ═══════════════════════════════════════════════════════════════════════════

    function _step3_deployOracle(
        DeployConfig.ChainConfig memory cfg,
        address admin
    ) internal {
        if (cfg.chainlinkPoRFeed != address(0)) {
            // Production chain with a known Chainlink PoR feed
            chainlinkAdapter = new ChainlinkPoRAdapter(
                cfg.chainlinkPoRFeed,
                cfg.maxOracleAge,
                cfg.maxDeviationBps,
                cfg.minCollateralRatio,
                admin
            );
            console.log("Step 3 - ChainlinkPoRAdapter deployed at:", address(chainlinkAdapter));

            // Wrap in OracleRouter for failover capability
            oracleRouter = new OracleRouter(
                address(chainlinkAdapter),
                cfg.maxDeviationBps,
                admin
            );
            console.log("Step 3 - OracleRouter deployed at:", address(oracleRouter));
        } else {
            // Testnet or chain without a PoR feed – deploy adapter with
            // placeholder; the feed address can be set post-deployment.
            chainlinkAdapter = new ChainlinkPoRAdapter(
                address(1), // Placeholder; will be replaced post-deploy
                cfg.maxOracleAge,
                cfg.maxDeviationBps,
                cfg.minCollateralRatio,
                admin
            );
            console.log("Step 3 - ChainlinkPoRAdapter (placeholder) deployed at:", address(chainlinkAdapter));

            oracleRouter = new OracleRouter(
                address(chainlinkAdapter),
                cfg.maxDeviationBps,
                admin
            );
            console.log("Step 3 - OracleRouter deployed at:", address(oracleRouter));
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STEP 4: SECURE MINT POLICY
    // ═══════════════════════════════════════════════════════════════════════════

    function _step4_deploySecureMintPolicy(
        address oracle,
        uint256 globalCap,
        uint256 epochCap,
        uint256 maxOracleAge,
        address admin
    ) internal {
        // Deploy with a temporary token address. The policy uses an immutable
        // `token` reference, so we must predict the BackedToken address or
        // accept that the token will be deployed next and the address linked
        // via the policy's IBackedToken interface.
        //
        // Strategy: deploy policy first referencing a future CREATE address.
        // The next contract deployed by this script will be BackedToken,
        // so we compute its address using deployer nonce + 1.
        address predictedToken = _predictNextCreate(msg.sender, vm.getNonce(msg.sender) + 1);

        secureMintPolicy = new SecureMintPolicy(
            predictedToken,
            oracle,
            globalCap,
            epochCap,
            maxOracleAge,
            admin
        );
        console.log("Step 4 - SecureMintPolicy deployed at:", address(secureMintPolicy));
        console.log("         (predicted token address):", predictedToken);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STEP 5: BACKED TOKEN
    // ═══════════════════════════════════════════════════════════════════════════

    function _step5_deployBackedToken(
        string memory name,
        string memory symbol,
        address guardian
    ) internal {
        backedToken = new BackedToken(
            name,
            symbol,
            address(secureMintPolicy),
            guardian
        );
        console.log("Step 5 - BackedToken deployed at:", address(backedToken));

        // Verify the predicted address matches
        require(
            address(backedToken) == address(secureMintPolicy.token()),
            "Deploy: BackedToken address mismatch with policy prediction"
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STEP 6: REDEMPTION + GOVERNANCE
    // ═══════════════════════════════════════════════════════════════════════════

    function _step6_deployRedemptionAndGovernance(
        address reserveAsset,
        address admin,
        address guardian,
        DeployConfig.ChainConfig memory cfg
    ) internal {
        // 6a. RedemptionEngine
        redemptionEngine = new RedemptionEngine(
            address(backedToken),
            reserveAsset,
            address(treasuryVault),
            admin
        );
        console.log("Step 6a - RedemptionEngine deployed at:", address(redemptionEngine));

        // 6b. Timelock
        address[] memory proposers = new address[](1);
        proposers[0] = admin; // Governor will be added after deployment
        address[] memory executors = new address[](1);
        executors[0] = address(0); // Anyone can execute after timelock
        timelock = new Timelock(
            cfg.timelockDelay,
            proposers,
            executors,
            admin
        );
        console.log("Step 6b - Timelock deployed at:", address(timelock));

        // 6c. Governor
        governor = new SecureMintGovernor(
            IVotes(address(backedToken)),
            TimelockController(payable(address(timelock))),
            guardian,
            cfg.votingDelay,
            cfg.votingPeriod,
            cfg.proposalThreshold,
            cfg.quorumPercentage
        );
        console.log("Step 6c - Governor deployed at:", address(governor));

        // Grant governor the PROPOSER_ROLE on timelock
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ROLE WIRING
    // ═══════════════════════════════════════════════════════════════════════════

    function _wireRoles(
        address admin,
        address guardian,
        address minter
    ) internal {
        console.log("Wiring roles...");

        // ── SecureMintPolicy Roles ──────────────────────────────────────────
        bytes32 MINTER_ROLE = secureMintPolicy.MINTER_ROLE();
        bytes32 GUARDIAN_ROLE = secureMintPolicy.GUARDIAN_ROLE();
        bytes32 GOVERNOR_ROLE = secureMintPolicy.GOVERNOR_ROLE();

        secureMintPolicy.grantRole(MINTER_ROLE, minter);
        secureMintPolicy.grantRole(GUARDIAN_ROLE, guardian);
        secureMintPolicy.grantRole(GOVERNOR_ROLE, address(timelock));
        console.log("  SecureMintPolicy: MINTER ->", minter);
        console.log("  SecureMintPolicy: GUARDIAN ->", guardian);
        console.log("  SecureMintPolicy: GOVERNOR -> Timelock");

        // ── EmergencyPause Roles ────────────────────────────────────────────
        bytes32 EP_GUARDIAN = emergencyPause.GUARDIAN_ROLE();
        bytes32 EP_GOVERNOR = emergencyPause.GOVERNOR_ROLE();
        bytes32 EP_MONITOR = emergencyPause.MONITOR_ROLE();

        emergencyPause.grantRole(EP_GUARDIAN, guardian);
        emergencyPause.grantRole(EP_GOVERNOR, address(timelock));
        emergencyPause.grantRole(EP_MONITOR, admin);
        console.log("  EmergencyPause: GUARDIAN ->", guardian);
        console.log("  EmergencyPause: GOVERNOR -> Timelock");
        console.log("  EmergencyPause: MONITOR ->", admin);

        // Register core contracts with EmergencyPause
        emergencyPause.registerContract(address(secureMintPolicy));
        emergencyPause.registerContract(address(treasuryVault));
        emergencyPause.registerContract(address(redemptionEngine));

        // ── TreasuryVault Roles ─────────────────────────────────────────────
        bytes32 TV_GUARDIAN = treasuryVault.GUARDIAN_ROLE();
        bytes32 TV_GOVERNOR = treasuryVault.GOVERNOR_ROLE();
        bytes32 TV_TREASURY_ADMIN = treasuryVault.TREASURY_ADMIN_ROLE();
        bytes32 TV_REBALANCER = treasuryVault.REBALANCER_ROLE();

        treasuryVault.grantRole(TV_GUARDIAN, guardian);
        treasuryVault.grantRole(TV_GOVERNOR, address(timelock));
        treasuryVault.grantRole(TV_TREASURY_ADMIN, admin);
        treasuryVault.grantRole(TV_REBALANCER, admin);
        console.log("  TreasuryVault: GUARDIAN ->", guardian);
        console.log("  TreasuryVault: GOVERNOR -> Timelock");

        // ── RedemptionEngine Roles ──────────────────────────────────────────
        bytes32 RE_GUARDIAN = redemptionEngine.GUARDIAN_ROLE();
        bytes32 RE_GOVERNOR = redemptionEngine.GOVERNOR_ROLE();
        bytes32 RE_TREASURY = redemptionEngine.TREASURY_ROLE();

        redemptionEngine.grantRole(RE_GUARDIAN, guardian);
        redemptionEngine.grantRole(RE_GOVERNOR, address(timelock));
        redemptionEngine.grantRole(RE_TREASURY, address(treasuryVault));
        console.log("  RedemptionEngine: GUARDIAN ->", guardian);
        console.log("  RedemptionEngine: GOVERNOR -> Timelock");

        // ── OracleRouter Roles ──────────────────────────────────────────────
        bytes32 ROUTER_ADMIN = oracleRouter.ROUTER_ADMIN();
        oracleRouter.grantRole(ROUTER_ADMIN, address(timelock));
        console.log("  OracleRouter: ROUTER_ADMIN -> Timelock");

        console.log("Role wiring complete.");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @dev Predict the address of a contract deployed via CREATE at a given nonce.
     */
    function _predictNextCreate(
        address deployer,
        uint64 nonce
    ) internal pure returns (address) {
        // RLP encoding for nonce-based CREATE address prediction
        if (nonce == 0x00) {
            return address(
                uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(0x80)))))
            );
        } else if (nonce <= 0x7f) {
            return address(
                uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, uint8(nonce)))))
            );
        } else if (nonce <= 0xff) {
            return address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(bytes1(0xd7), bytes1(0x94), deployer, bytes1(0x81), uint8(nonce))
                        )
                    )
                )
            );
        } else if (nonce <= 0xffff) {
            return address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xd8), bytes1(0x94), deployer, bytes1(0x82), uint16(nonce)
                            )
                        )
                    )
                )
            );
        } else {
            revert("Deploy: nonce too large for CREATE prediction");
        }
    }

    /**
     * @dev Read an address from env, falling back to a default value.
     */
    function _envOrDefault(
        string memory key,
        address defaultValue
    ) internal view returns (address) {
        try vm.envAddress(key) returns (address val) {
            return val == address(0) ? defaultValue : val;
        } catch {
            return defaultValue;
        }
    }

    /**
     * @dev Read an address from env, falling back to a provided fallback.
     */
    function _envOr(
        string memory key,
        address fallback_
    ) internal view returns (address) {
        try vm.envAddress(key) returns (address val) {
            return val == address(0) ? fallback_ : val;
        } catch {
            return fallback_;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // LOGGING
    // ═══════════════════════════════════════════════════════════════════════════

    function _logDeployment() internal view {
        console.log("");
        console.log("========================================");
        console.log("  SecureMintEngine Deployment Summary");
        console.log("========================================");
        console.log("  Chain ID          :", block.chainid);
        console.log("  BackedToken       :", address(backedToken));
        console.log("  EmergencyPause    :", address(emergencyPause));
        console.log("  TreasuryVault     :", address(treasuryVault));
        console.log("  ChainlinkAdapter  :", address(chainlinkAdapter));
        console.log("  OracleRouter      :", address(oracleRouter));
        console.log("  SecureMintPolicy  :", address(secureMintPolicy));
        console.log("  RedemptionEngine  :", address(redemptionEngine));
        console.log("  Timelock          :", address(timelock));
        console.log("  Governor          :", address(governor));
        console.log("========================================");
    }
}
