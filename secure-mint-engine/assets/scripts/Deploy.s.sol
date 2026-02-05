// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/BackedToken.sol";
import "../contracts/ChainlinkPoRAdapter.sol";
import "../contracts/SecureMintPolicy.sol";
import "../contracts/TreasuryVault.sol";
import "../contracts/EmergencyPause.sol";
import "../contracts/Timelock.sol";
import "../contracts/OracleRouter.sol";
import "../contracts/Governor.sol";
import "../contracts/RedemptionEngine.sol";
import "../contracts/GuardianMultisig.sol";
import "./DeployConfig.s.sol";

/**
 * @title Deploy
 * @author SecureMintEngine
 * @notice Foundry deployment script for the full SecureMintEngine protocol stack.
 *
 * @dev Deployment order:
 *
 *      Phase 1 — Core contracts:
 *
 *      1. BackedToken           — The ERC-20 "dumb ledger"
 *      2. ChainlinkPoRAdapter   — IBackingOracle adapter wrapping a Chainlink PoR feed
 *      3. SecureMintPolicy      — Oracle-gated mint policy (core logic)
 *      4. TreasuryVault         — 4-tier collateral custody
 *      5. EmergencyPause        — Graduated circuit breaker
 *      6. Timelock              — Governance timelock controller
 *
 *      Phase 2 — Governance contracts:
 *
 *      7. OracleRouter          — Multi-oracle router with fallback
 *      8. Governor              — Lightweight on-chain DAO governance
 *      9. RedemptionEngine      — Burn-to-redeem mechanism
 *     10. GuardianMultisig      — Multisig for guardian emergency actions
 *
 *      After deployment, cross-references are wired:
 *        - MINTER_ROLE on BackedToken  -> SecureMintPolicy
 *        - PAUSER_ROLE on BackedToken  -> EmergencyPause
 *        - EmergencyPause address      -> SecureMintPolicy.setEmergencyPause()
 *        - GUARDIAN_ROLE on SecureMintPolicy -> guardian address
 *        - GUARDIAN_ROLE on EmergencyPause   -> guardian address
 *        - OPERATOR_ROLE on SecureMintPolicy -> operator address
 *        - TREASURER_ROLE on TreasuryVault   -> treasurer address
 *        - OPERATOR_ROLE on TreasuryVault    -> operator address
 *        - DAO_ROLE on EmergencyPause        -> dao address
 *        - GUARDIAN_ROLE on EmergencyPause   -> GuardianMultisig
 *        - PROPOSER_ROLE on Timelock         -> Governor
 *
 *      Usage:
 *        forge script scripts/Deploy.s.sol:Deploy \
 *          --rpc-url $RPC_URL \
 *          --broadcast \
 *          --verify \
 *          -vvvv
 */
contract Deploy is Script {
    // -------------------------------------------------------------------
    //  Deployed Contract References — Phase 1 (Core)
    // -------------------------------------------------------------------

    BackedToken public backedToken;
    ChainlinkPoRAdapter public chainlinkAdapter;
    SecureMintPolicy public secureMintPolicy;
    TreasuryVault public treasuryVault;
    EmergencyPause public emergencyPause;
    Timelock public timelock;

    // -------------------------------------------------------------------
    //  Deployed Contract References — Phase 2 (Governance)
    // -------------------------------------------------------------------

    OracleRouter public oracleRouter;
    Governor public governor;
    RedemptionEngine public redemptionEngine;
    GuardianMultisig public guardianMultisig;

    // -------------------------------------------------------------------
    //  Shared Configuration
    // -------------------------------------------------------------------

    DeployConfig.DeploymentConfig internal cfg;

    // -------------------------------------------------------------------
    //  Main Entry Point
    // -------------------------------------------------------------------

    function run() external {
        // ---------------------------------------------------------------
        //  Step 0: Load configuration
        // ---------------------------------------------------------------
        console.log("=== SecureMintEngine Deployment ===");
        console.log("");

        cfg = DeployConfig.getConfigFromEnv(vm);

        console.log("Configuration loaded:");
        console.log("  admin:            ", cfg.admin);
        console.log("  oracleAggregator: ", cfg.oracleAggregator);
        console.log("  collateralToken:  ", cfg.collateralToken);
        console.log("  guardian:         ", cfg.guardian);
        console.log("  operator:         ", cfg.operator);
        console.log("  treasurer:        ", cfg.treasurer);
        console.log("  dao:              ", cfg.dao);
        console.log("  feeRecipient:     ", cfg.feeRecipient);
        console.log("  tokenName:        ", cfg.tokenName);
        console.log("  tokenSymbol:      ", cfg.tokenSymbol);
        console.log("  globalCap:        ", cfg.globalCap);
        console.log("  epochCap:         ", cfg.epochCap);
        console.log("  epochDuration:    ", cfg.epochDuration);
        console.log("  maxStaleness:     ", cfg.maxStaleness);
        console.log("  maxDeviation:     ", cfg.maxDeviation);
        console.log("  timelockDelay:    ", cfg.timelockDelay);
        console.log("");

        // Validate required addresses
        require(cfg.admin != address(0), "Deploy: DEPLOY_ADMIN not set");
        require(cfg.oracleAggregator != address(0), "Deploy: DEPLOY_ORACLE_AGGREGATOR not set");
        require(cfg.collateralToken != address(0), "Deploy: DEPLOY_COLLATERAL_TOKEN not set");
        require(cfg.guardian != address(0), "Deploy: DEPLOY_GUARDIAN not set");
        require(cfg.operator != address(0), "Deploy: DEPLOY_OPERATOR not set");
        require(cfg.treasurer != address(0), "Deploy: DEPLOY_TREASURER not set");
        require(cfg.dao != address(0), "Deploy: DEPLOY_DAO not set");
        require(cfg.feeRecipient != address(0), "Deploy: DEPLOY_FEE_RECIPIENT not set");

        vm.startBroadcast();

        // ---------------------------------------------------------------
        //  Step 1: Deploy BackedToken
        // ---------------------------------------------------------------
        console.log("[1/6] Deploying BackedToken...");

        backedToken = new BackedToken(
            cfg.tokenName,
            cfg.tokenSymbol,
            cfg.tokenDecimals,
            cfg.admin
        );

        console.log("  BackedToken deployed at:", address(backedToken));

        // ---------------------------------------------------------------
        //  Step 2: Deploy ChainlinkPoRAdapter (IBackingOracle)
        // ---------------------------------------------------------------
        console.log("[2/6] Deploying ChainlinkPoRAdapter...");

        chainlinkAdapter = new ChainlinkPoRAdapter(
            cfg.oracleAggregator,
            cfg.maxStaleness,
            cfg.maxDeviation,
            cfg.admin
        );

        console.log("  ChainlinkPoRAdapter deployed at:", address(chainlinkAdapter));

        // ---------------------------------------------------------------
        //  Step 3: Deploy SecureMintPolicy
        // ---------------------------------------------------------------
        console.log("[3/6] Deploying SecureMintPolicy...");

        secureMintPolicy = new SecureMintPolicy(
            address(backedToken),
            address(chainlinkAdapter),
            cfg.globalCap,
            cfg.epochCap,
            cfg.epochDuration,
            cfg.maxStaleness,
            cfg.maxDeviation,
            cfg.timelockDelay,
            cfg.admin
        );

        console.log("  SecureMintPolicy deployed at:", address(secureMintPolicy));

        // ---------------------------------------------------------------
        //  Step 4: Deploy TreasuryVault
        // ---------------------------------------------------------------
        console.log("[4/6] Deploying TreasuryVault...");

        treasuryVault = new TreasuryVault(
            cfg.collateralToken,
            address(backedToken),
            address(chainlinkAdapter),
            cfg.admin
        );

        console.log("  TreasuryVault deployed at:", address(treasuryVault));

        // ---------------------------------------------------------------
        //  Step 5: Deploy EmergencyPause
        // ---------------------------------------------------------------
        console.log("[5/6] Deploying EmergencyPause...");

        emergencyPause = new EmergencyPause(
            cfg.admin,
            cfg.fullFreezeTimelockDelay,
            cfg.cooldownPeriod,
            address(backedToken),
            address(secureMintPolicy)
        );

        console.log("  EmergencyPause deployed at:", address(emergencyPause));

        // ---------------------------------------------------------------
        //  Step 6: Deploy Timelock (Governance)
        // ---------------------------------------------------------------
        console.log("[6/6] Deploying Timelock...");

        address[] memory proposers = new address[](1);
        proposers[0] = cfg.admin;

        address[] memory executors = new address[](1);
        executors[0] = cfg.admin;

        address[] memory cancellers = new address[](1);
        cancellers[0] = cfg.admin;

        timelock = new Timelock(
            cfg.governanceTimelockMinDelay,
            cfg.admin,
            proposers,
            executors,
            cancellers
        );

        console.log("  Timelock deployed at:", address(timelock));

        // ---------------------------------------------------------------
        //  Step 7: Wire cross-references and grant roles (Core)
        // ---------------------------------------------------------------
        console.log("");
        console.log("Wiring cross-references...");

        // Grant MINTER_ROLE on BackedToken to SecureMintPolicy
        console.log("  Granting MINTER_ROLE on BackedToken to SecureMintPolicy...");
        backedToken.grantRole(backedToken.MINTER_ROLE(), address(secureMintPolicy));

        // Grant PAUSER_ROLE on BackedToken to EmergencyPause
        console.log("  Granting PAUSER_ROLE on BackedToken to EmergencyPause...");
        backedToken.grantRole(backedToken.PAUSER_ROLE(), address(emergencyPause));

        // Set EmergencyPause address on SecureMintPolicy
        console.log("  Setting EmergencyPause on SecureMintPolicy...");
        secureMintPolicy.setEmergencyPause(address(emergencyPause));

        // Grant GUARDIAN_ROLE on SecureMintPolicy to the guardian
        console.log("  Granting GUARDIAN_ROLE on SecureMintPolicy to guardian...");
        secureMintPolicy.grantRole(secureMintPolicy.GUARDIAN_ROLE(), cfg.guardian);

        // Grant GUARDIAN_ROLE on EmergencyPause to the guardian
        console.log("  Granting GUARDIAN_ROLE on EmergencyPause to guardian...");
        emergencyPause.grantRole(emergencyPause.GUARDIAN_ROLE(), cfg.guardian);

        // Grant OPERATOR_ROLE on SecureMintPolicy to the operator
        console.log("  Granting OPERATOR_ROLE on SecureMintPolicy to operator...");
        secureMintPolicy.grantRole(secureMintPolicy.OPERATOR_ROLE(), cfg.operator);

        // Grant TREASURER_ROLE on TreasuryVault to the treasurer
        console.log("  Granting TREASURER_ROLE on TreasuryVault to treasurer...");
        treasuryVault.grantRole(treasuryVault.TREASURER_ROLE(), cfg.treasurer);

        // Grant OPERATOR_ROLE on TreasuryVault to the operator
        console.log("  Granting OPERATOR_ROLE on TreasuryVault to operator...");
        treasuryVault.grantRole(treasuryVault.OPERATOR_ROLE(), cfg.operator);

        // Grant DAO_ROLE on EmergencyPause to the DAO
        console.log("  Granting DAO_ROLE on EmergencyPause to dao...");
        emergencyPause.grantRole(emergencyPause.DAO_ROLE(), cfg.dao);

        // ---------------------------------------------------------------
        //  Step 8: Deploy governance contracts (Phase 2)
        // ---------------------------------------------------------------
        deployGovernance();

        vm.stopBroadcast();

        // ---------------------------------------------------------------
        //  Step 9: Log deployment summary
        // ---------------------------------------------------------------
        console.log("");
        console.log("=== Deployment Summary ===");
        console.log("");
        console.log("  --- Phase 1 (Core) ---");
        console.log("  BackedToken:         ", address(backedToken));
        console.log("  ChainlinkPoRAdapter: ", address(chainlinkAdapter));
        console.log("  SecureMintPolicy:    ", address(secureMintPolicy));
        console.log("  TreasuryVault:       ", address(treasuryVault));
        console.log("  EmergencyPause:      ", address(emergencyPause));
        console.log("  Timelock:            ", address(timelock));
        console.log("");
        console.log("  --- Phase 2 (Governance) ---");
        console.log("  OracleRouter:        ", address(oracleRouter));
        console.log("  Governor:            ", address(governor));
        console.log("  RedemptionEngine:    ", address(redemptionEngine));
        console.log("  GuardianMultisig:    ", address(guardianMultisig));
        console.log("");
        console.log("  --- Addresses ---");
        console.log("  Admin:               ", cfg.admin);
        console.log("  Guardian:            ", cfg.guardian);
        console.log("  Operator:            ", cfg.operator);
        console.log("  Treasurer:           ", cfg.treasurer);
        console.log("  DAO:                 ", cfg.dao);
        console.log("  Fee Recipient:       ", cfg.feeRecipient);
        console.log("  Oracle Aggregator:   ", cfg.oracleAggregator);
        console.log("  Collateral Token:    ", cfg.collateralToken);
        console.log("");
        console.log("=== Role Assignments ===");
        console.log("");
        console.log("  BackedToken.MINTER_ROLE          -> SecureMintPolicy");
        console.log("  BackedToken.PAUSER_ROLE          -> EmergencyPause");
        console.log("  SecureMintPolicy.emergencyPause  -> EmergencyPause");
        console.log("  SecureMintPolicy.GUARDIAN_ROLE    -> Guardian");
        console.log("  SecureMintPolicy.OPERATOR_ROLE   -> Operator");
        console.log("  TreasuryVault.TREASURER_ROLE     -> Treasurer");
        console.log("  TreasuryVault.OPERATOR_ROLE      -> Operator");
        console.log("  TreasuryVault.OPERATOR_ROLE      -> RedemptionEngine");
        console.log("  EmergencyPause.GUARDIAN_ROLE      -> Guardian");
        console.log("  EmergencyPause.GUARDIAN_ROLE      -> GuardianMultisig");
        console.log("  EmergencyPause.DAO_ROLE           -> DAO");
        console.log("  Timelock.PROPOSER_ROLE            -> Governor");
        console.log("");
        console.log("=== Deployment Complete ===");
    }

    // -------------------------------------------------------------------
    //  Phase 2: Governance Contracts
    // -------------------------------------------------------------------

    /**
     * @notice Deploys the governance layer contracts (OracleRouter, Governor,
     *         RedemptionEngine, GuardianMultisig) and wires their roles.
     * @dev Can be called independently if Phase 1 contracts are already deployed
     *      and their addresses are set on this contract's state variables.
     */
    function deployGovernance() public {
        console.log("");
        console.log("=== Phase 2: Governance Deployment ===");
        console.log("");

        // ---------------------------------------------------------------
        //  Step 7a: Deploy OracleRouter
        // ---------------------------------------------------------------
        console.log("[7/10] Deploying OracleRouter...");

        oracleRouter = new OracleRouter(
            address(chainlinkAdapter),
            cfg.admin
        );

        console.log("  OracleRouter deployed at:", address(oracleRouter));

        // ---------------------------------------------------------------
        //  Step 7b: Deploy Governor
        // ---------------------------------------------------------------
        console.log("[8/10] Deploying Governor...");

        governor = new Governor(
            cfg.governorQuorum,
            cfg.governorVotingPeriod,
            cfg.admin
        );

        console.log("  Governor deployed at:", address(governor));

        // ---------------------------------------------------------------
        //  Step 7c: Deploy RedemptionEngine
        // ---------------------------------------------------------------
        console.log("[9/10] Deploying RedemptionEngine...");

        redemptionEngine = new RedemptionEngine(
            address(backedToken),
            address(treasuryVault),
            cfg.collateralToken,
            cfg.feeRecipient,
            cfg.admin
        );

        console.log("  RedemptionEngine deployed at:", address(redemptionEngine));

        // Grant RedemptionEngine OPERATOR_ROLE on TreasuryVault so it can withdraw collateral during redemptions
        console.log("  Granting OPERATOR_ROLE on TreasuryVault to RedemptionEngine...");
        treasuryVault.grantRole(treasuryVault.OPERATOR_ROLE(), address(redemptionEngine));

        // ---------------------------------------------------------------
        //  Step 7d: Deploy GuardianMultisig
        // ---------------------------------------------------------------
        console.log("[10/10] Deploying GuardianMultisig...");

        address[] memory guardians = new address[](1);
        guardians[0] = cfg.guardian;

        guardianMultisig = new GuardianMultisig(
            guardians,
            cfg.guardianMultisigRequired
        );

        console.log("  GuardianMultisig deployed at:", address(guardianMultisig));

        // ---------------------------------------------------------------
        //  Wire governance roles
        // ---------------------------------------------------------------
        console.log("");
        console.log("Wiring governance roles...");

        // Grant GUARDIAN_ROLE on EmergencyPause to GuardianMultisig
        console.log("  Granting GUARDIAN_ROLE on EmergencyPause to GuardianMultisig...");
        emergencyPause.grantRole(emergencyPause.GUARDIAN_ROLE(), address(guardianMultisig));

        // Grant PROPOSER_ROLE on Timelock to Governor
        console.log("  Granting PROPOSER_ROLE on Timelock to Governor...");
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));

        // NOTE: Admin retains PROPOSER_ROLE, EXECUTOR_ROLE, and CANCELLER_ROLE on Timelock
        // for the initial bootstrapping period. These should be revoked via a governance
        // proposal after the system is stable and the Governor has proven operational.
        // To revoke: timelock.revokeRole(PROPOSER_ROLE, admin), etc.

        console.log("");
        console.log("=== Phase 2 Complete ===");
    }
}
