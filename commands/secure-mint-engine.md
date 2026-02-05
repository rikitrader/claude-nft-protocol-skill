---
name: secure-mint-engine
description: "Priority engine for oracle-gated secure minting in blockchain token systems. This skill MUST be activated when designing any token that claims backing, stability, or reserve-based value such as stablecoins and asset-backed tokens. Enforces the follow-the-money doctrine where tokens may ONLY be minted if backing is provably sufficient via on-chain oracles or Proof-of-Reserve feeds. Takes priority over all other token mint designs when backing claims exist. Includes Phase 0 Market Intelligence Engine, Monetary Routing Decision Tree, and CI guardrails for production deployment. Use when money_mechanic_type equals stablecoin_backed, backing_type is not none, project claims 1:1 backing or fully backed or redeemable, token marketed as stable or asset-backed or reserve-backed, or treasury/reserves justify minting."
version: 1.0.0
author: Ricardo Prieto
source: ~/.claude/commands/secure-mint-engine.md
changelog:
  - 1.0.0: Complete rewrite as slim orchestrator. All heavy logic delegated to sub-commands.
---

# SecureMintEngine v1.0 -- Oracle-Gated Secure Mint Orchestrator

    +===============================================================+
    |  SECURE       MINT       ENGINE                               |
    |  ███████╗███████╗ ██████╗██╗   ██╗██████╗ ███████╗            |
    |  ██╔════╝██╔════╝██╔════╝██║   ██║██╔══██╗██╔════╝            |
    |  ███████╗█████╗  ██║     ██║   ██║██████╔╝█████╗              |
    |  ╚════██║██╔══╝  ██║     ██║   ██║██╔══██╗██╔══╝              |
    |  ███████║███████╗╚██████╗╚██████╔╝██║  ██║███████╗            |
    |  ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝            |
    |          ███╗   ███╗██╗███╗   ██╗████████╗                    |
    |          ████╗ ████║██║████╗  ██║╚══██╔══╝                    |
    |          ██╔████╔██║██║██╔██╗ ██║   ██║                       |
    |          ██║╚██╔╝██║██║██║╚██╗██║   ██║                       |
    |          ██║ ╚═╝ ██║██║██║ ╚████║   ██║                       |
    |          ╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝   ╚═╝                       |
    |           Oracle-Gated Secure Minting Protocol                |
    +===============================================================+

> **Follow-the-Money Doctrine**: If backing cannot be proven ON-CHAIN or via trusted Proof-of-Reserve feeds, THE TOKEN MUST NOT BE MINTABLE.

---

## Quick Start Intake

Ask the user this FIRST before any work begins:

    Where would you like me to create the project files?

    Please provide:
    1. OUTPUT FOLDER PATH  (e.g., /Users/you/projects/my-token)
    2. TOKEN NAME           (e.g., USDX, VESD, MyStable)
    3. TOKEN SYMBOL         (e.g., USDX, VSD, MST)
    4. BACKING TYPE         (fiat_reserves / crypto_collateral / RWA / none)
    5. TARGET CHAINS        (ethereum / polygon / arbitrum / solana / multi-chain)
    6. RISK TOLERANCE       (low / medium / high)
    7. CROSS-CHAIN?         (yes / no)

Example:

    Build me a stablecoin called USDX:
    - Backing: fiat_reserves
    - Chains: ethereum, arbitrum
    - Risk tolerance: low
    - Cross-chain: yes
    - Output folder: /tmp/usdx-protocol

---

## Execution Flow (Locked Order)

    STEP 0    Output Folder Setup
        |
    STEP 0.5  Financial Feasibility Gate  [HARD GATE -- REJECT = STOP]
        |
    PHASE 0   Market Intelligence Engine (/secure-mint-market-intel)
        |     -> Produces DECISION_CONTEXT.json
    PHASE 1   Business Plan Generator (/secure-mint-business-plan)
        |     -> 5000+ word plan with 50+ tasks
        |
        |     Chain Detection -> Routing Decision
        |       /         \
        |    SOLANA       EVM
        |      |            |
        |    [MEMECOIN]   Monetary Routing Tree
        |                 +- [FIXED]       Fixed supply
        |                 +- [EMISSIONS]   Incentive tokens
        |                 +- [SECURE_MINT] Backed tokens (this engine)
        |
    STEPS 1-8  Smart Contract Generation (/secure-mint-contracts)
        |
    GATES 1-4  God-Tier Launch Gates (/secure-mint-launch-gates)
        |
    DEPLOY     Deployment & CI/CD (/secure-mint-deployment)

---

## Step 0: Output Folder Setup

Use the answers from the Quick Start Intake to create this structure:

    [OUTPUT_FOLDER]/
    +-- README.md
    +-- docs/
    |   +-- BUSINESS_PLAN.md
    |   +-- WHITEPAPER.md
    |   +-- architecture/
    +-- intake/
    |   +-- PROJECT_CONTEXT.json
    |   +-- DECISION_CONTEXT.json
    +-- config/
    |   +-- WEIGHTS.json
    |   +-- ELIMINATION_RULES.json
    +-- contracts/
    |   +-- token/
    |   +-- policy/
    |   +-- oracle/
    |   +-- treasury/
    |   +-- governance/
    |   +-- emergency/
    +-- scripts/
    |   +-- deploy/
    |   +-- ci/
    +-- test/
    |   +-- unit/
    |   +-- integration/
    |   +-- invariant/
    +-- .github/workflows/

---

## Step 0.5: Financial Feasibility Report (MANDATORY GATE)

**HARD GATE** — No implementation until this report is generated, reviewed, and signed off.

Generate a report covering: one-time costs, monthly operating costs, revenue projections, 24-month P&L, break-even analysis, ROI scenarios, runway calculation.

**Required signatures:** Project Lead, CFO/Finance, Legal Counsel, Technical Lead.

**The intake command will FAIL if no approved financial report exists.**

---

## Phase Delegation (Sub-Commands)

| Phase | Sub-Command | Purpose |
|-------|-------------|---------|
| Phase 0 | `/secure-mint-market-intel` | Market research, chain selection, DECISION_CONTEXT.json |
| Phase 1 | `/secure-mint-business-plan` | 5000+ word business plan, whitepaper, financial model |
| Steps 1-8 | `/secure-mint-contracts` | Smart contract generation, invariants, threat modeling |
| Gates 1-4 | `/secure-mint-launch-gates` | Legal, audit, stress test, launch countdown |
| Deploy | `/secure-mint-deployment` | CI guardrails, preflight, smoke tests, Python engine |

Load each sub-command when its phase begins. Read its reference files from `~/.claude/secure-mint-engine/`.

---

## Monetary Routing Decision Tree

    TOKEN DESIGN START
           |
      Which chain?
       /         \
    SOLANA       EVM
      |            |
      v            v
    [MEMECOIN]   Minting after TGE?
                  /        \
                NO          YES
                |            |
           [FIXED]     Backed by reserves?
                        /        \
                      NO          YES
                      |            |
                [EMISSIONS]   [SECURE_MINT]  <-- THIS ENGINE

**Route Markers (for CI):** `[ROUTE:FIXED]` `[ROUTE:EMISSIONS]` `[ROUTE:SECURE_MINT]` `[ROUTE:CROSS_CHAIN]` `[ROUTE:MEMECOIN]`

---

## Auto-Detection Triggers

| Phrase Detected | Action |
|-----------------|--------|
| "stablecoin", "backed token", "reserve-backed", "1:1 backing" | Full SecureMint workflow |
| "oracle-gated", "proof of reserve" | SecureMint + Oracle setup |
| "cross-chain token" | SecureMint + Bridge |
| "mint policy" | Policy contract generation |
| "memecoin", "solana token", "raydium", "jupiter", "pump.fun" | Memecoin Execution Layer |
| "SPL token", "anchor program", "fixed supply token" | Memecoin Execution Layer |

---

## Activation Triggers (Mandatory)

Activate SecureMintEngine if ANY of:
- `money_mechanic_type == "stablecoin_backed"`
- `backing_type != "none"`
- Project claims "1:1 backing", "fully backed", "redeemable"
- Token marketed as "stable", "asset-backed", "reserve-backed"
- Treasury/reserves referenced as justification for minting

**If triggered, NO OTHER MINT SYSTEM MAY BYPASS THIS ENGINE.**

---

## Core Architecture

    [ ERC-20 Token (DUMB LEDGER) ]
                 |
    [ SecureMint Policy Contract ] -- Mint allowed IFF ALL conditions hold
                 |
    [ Proof-of-Reserve / Oracle Feeds ]
                 |
    [ Emergency Pause + Governance Controls ]

**Mint Conditions (ALL must hold):**
1. Verified backing >= post-mint totalSupply
2. Oracle reports healthy (not stale, not deviated)
3. Mint amount <= per-epoch rate limit
4. totalSupply + amount <= global supply cap
5. Contract is NOT paused
6. Caller has MINTER_ROLE

**If ANY fails → `mint()` MUST revert.**

---

## File Ecosystem

All supporting files live under `~/.claude/secure-mint-engine/`:

    ~/.claude/secure-mint-engine/
    |
    +-- references/
    |   +-- market-intelligence-engine.md    Phase 0 meta prompt
    |   +-- risk-scoring-engine.md           Risk-tolerance scoring
    |   +-- live-data-hooks-engine.md        Live data hooks (TVL, exploits)
    |   +-- auto-elimination-engine.md       Programmatic fail rules
    |   +-- memecoin-execution-layer.md      Solana memecoin system (28+ files)
    |   +-- oracle-requirements.md           Oracle/PoR specs
    |   +-- invariants.md                    Formal invariants (INV-SM-1..4)
    |   +-- threat-matrix.md                 Threat modeling
    |   +-- monetary-theory-foundations.md   Modern Money Mechanics
    |   +-- blockchain-ecosystem.md          Core repos, tools, protocols
    |   +-- github-architecture-map.md       Repo setup, permissions, CI
    |   +-- business-plan-template.md        5000+ word template
    |   +-- deep-report-template.md          Institutional-grade report
    |
    +-- assets/
    |   +-- contracts/
    |   |   +-- BackedToken.sol              ERC-20 dumb ledger
    |   |   +-- SecureMintPolicy.sol         Oracle-gated mint policy (epoch fix + timelocked setters)
    |   |   +-- IBackingOracle.sol           Oracle interface
    |   |   +-- IBackedToken.sol             BackedToken interface
    |   |   +-- ISecureMintPolicy.sol        SecureMintPolicy interface
    |   |   +-- ITreasuryVault.sol           TreasuryVault interface
    |   |   +-- IEmergencyPause.sol          EmergencyPause interface
    |   |   +-- EmergencyPause.sol           4-level circuit breaker
    |   |   +-- TreasuryVault.sol            4-tier reserve custody
    |   |   +-- ChainlinkPoRAdapter.sol      Chainlink PoR oracle adapter
    |   |   +-- OracleRouter.sol             Multi-oracle router with fallback
    |   |   +-- Governor.sol                 Lightweight DAO governance
    |   |   +-- Timelock.sol                 Time-delayed execution controller
    |   |   +-- RedemptionEngine.sol         Burn-to-redeem mechanism
    |   |   +-- GuardianMultisig.sol         Lightweight multisig
    |   |
    |   +-- test/
    |   |   +-- mocks/
    |   |   |   +-- MockOracle.sol           Configurable mock oracle
    |   |   |   +-- MockERC20.sol            Mock ERC-20 for testing
    |   |   +-- unit/
    |   |   |   +-- BackedToken.t.sol        BackedToken unit tests
    |   |   |   +-- SecureMintPolicy.t.sol   SecureMintPolicy unit tests
    |   |   |   +-- TreasuryVault.t.sol      TreasuryVault unit tests
    |   |   |   +-- EmergencyPause.t.sol     EmergencyPause unit tests
    |   |   +-- invariant/
    |   |       +-- Invariants.t.sol         INV-SM-1..4 invariant tests
    |   |
    |   +-- scripts/
    |   |   +-- DeployConfig.s.sol           Deployment configuration library
    |   |   +-- Deploy.s.sol                 Full deployment script (6-step)
    |   |
    |   +-- .github/workflows/
    |   |   +-- test.yml                     Test suite (unit/integration/invariant/python)
    |   |   +-- security.yml                 Security scanning (Slither/Mythril/Solhint)
    |   |   +-- monetary_routing.yml         Monetary routing CI check
    |   |   +-- deploy.yml                   Manual deployment pipeline
    |   |
    |   +-- .slither.config.json             Slither configuration
    |   +-- .solhint.json                    Solhint linter configuration
    |   +-- foundry.toml                     Foundry project configuration
    |   +-- remappings.txt                   Import remappings
    |   |
    |   +-- python-engine/
    |       +-- securemint_cli.py            CLI (15 subcommands)
    |       +-- Makefile                     Make commands (50+ targets)
    |       +-- requirements.txt             Dependencies
    |       +-- .env.example                 Environment variable template
    |       +-- tests/
    |           +-- __init__.py              Test package
    |           +-- test_cli.py              17 pytest tests for CLI
    |
    +-- diagrams/
    |   +-- FullSystemWorkflow.ascii         Complete system flow
    |   +-- MonetaryRouting.ascii            Decision tree
    |   +-- MasterProtocolControlPanel.ascii Unified control panel
    |   +-- StablecoinMintBurnFlow.ascii     Mint/burn lifecycle
    |   +-- OracleGatedSecurityModel.ascii   Oracle validation
    |   +-- RiskScoringEngine.ascii          Real-time risk (9 metrics)
    |   +-- GovernanceControlFlow.ascii      DAO proposal lifecycle
    |   +-- EmergencyShutdownArchitecture.ascii  4-level shutdown
    |   +-- TreasuryReserveArchitecture.ascii    4-tier reserves
    |   +-- DeFiLiquidityRoutingEngine.ascii Yield optimization
    |   +-- CrossChainBridgeSecurity.ascii   Lock-mint bridge
    |   +-- PegStabilityMechanics.ascii      5-layer peg defense
    |
    +-- scripts/
        +-- monetary_routing_ci_check.py     CI guardrail

Sub-commands (in ~/.claude/commands/):

    secure-mint-market-intel.md    Phase 0 Market Intelligence
    secure-mint-business-plan.md   Phase 1 Business Plan
    secure-mint-contracts.md       Smart Contract Generation (Steps 1-8)
    secure-mint-launch-gates.md    God-Tier Launch Gates (Gates 1-4)
    secure-mint-deployment.md      Deployment and CI/CD

---

## Python Engine Execution Rules (MANDATORY)

**Location:** `~/.claude/secure-mint-engine/assets/python-engine/`

> **ABSOLUTE RULE:** NEVER load bulk data (>10 items) through context. Execute Python CLI via Bash tool.

### Setup (First Use)

    cd ~/.claude/secure-mint-engine/assets/python-engine
    cp .env.example .env        # Edit with your RPC URL, keys, addresses
    pip install -r requirements.txt
    make health-check           # Verify everything works

### Operation Routing Table

| Operation | Method | Bash Command |
|-----------|--------|-------------|
| Batch mint (>1 address) | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine mint FILE=<path>` |
| Dry-run batch mint | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine mint-dry FILE=<path>` |
| Compliance check (single) | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine compliance ADDRESS=0x...` |
| Compliance check (bulk) | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine compliance-bulk ADDR_FILE=<path>` |
| Report generation | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine report TYPE=<reserve\|monthly\|treasury\|compliance\|bridge>` |
| All reports | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine reports-all` |
| Oracle health check | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine oracle-status` |
| Invariant check | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine invariants` |
| TX simulation | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine simulate BUNDLE=<path>` |
| Config validation | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine validate-config` |
| Contract validation | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine validate-contracts` |
| Full health dashboard | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine health-check` |
| Batch burn | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine burn FILE=<path>` |
| Treasury status | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine treasury-status` |
| Bridge status | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine bridge-status` |
| Smoke tests (9 checks) | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine smoke-test` |
| Preflight checks | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine preflight` |
| Intake checklist | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine intake` |
| Compliance AML-only | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine compliance-aml ADDR_FILE=<path>` |
| Compliance sanctions-only | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine compliance-sanctions ADDR_FILE=<path>` |
| Full production deploy | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine production-deploy` |
| Build contracts | **Foundry** | `make -C ~/.claude/secure-mint-engine/assets/python-engine contracts` |
| Run Foundry tests | **Foundry** | `make -C ~/.claude/secure-mint-engine/assets/python-engine check` |
| Full validation suite | **Both** | `make -C ~/.claude/secure-mint-engine/assets/python-engine validate` |
| Launch gates | **Python CLI** | `make -C ~/.claude/secure-mint-engine/assets/python-engine full-gates` |
| Single address lookup | Context OK | Read from chain via context |
| Architecture discussion | Context OK | No bulk data needed |
| Contract design/review | Context OK | Read Solidity files directly |

### Token Reduction

| Operation | Without Python Engine | With Python Engine | Reduction |
|-----------|----------------------|-------------------|-----------|
| Batch mint 1000 addresses | ~50,000 tokens | ~500 tokens | **99%** |
| Compliance check 500 addrs | ~25,000 tokens | ~300 tokens | **98.8%** |
| Generate all reports | ~20,000 tokens | ~200 tokens | **99%** |
| Check invariants | ~5,000 tokens | ~100 tokens | **98%** |

### When Claude MUST Use Python Engine

1. ANY batch operation with >10 items
2. ANY compliance check (even single address)
3. ALL report generation
4. ALL oracle/invariant monitoring
5. ALL transaction simulations

### When Context Is Acceptable

1. Reading/reviewing Solidity source code
2. Architecture and design discussions
3. Single on-chain value lookups during design
4. Explaining contract logic to the user

---

## Absolute Rule (Follow-the-Money Doctrine)

> If backing cannot be proven ON-CHAIN or via trusted Proof-of-Reserve feeds,
> THE TOKEN MUST NOT BE MINTABLE.

Claims about backing without cryptographic enforcement are treated as a **HIGH-RISK / FRAUD VECTOR**.

**NO "TEMPORARY UNLIMITED MINT" IS EVER ALLOWED.**

---

## Knowledge Sources

- Modern Money Mechanics (Federal Reserve) -- money creation in banking
- Understanding Money Mechanics (Robert Murphy) -- money, banking, monetary creation
- Monetary Economics (Handa) -- monetary theory and policy
- Monetary Economics (Godley and Lavoie) -- credit, money, and income

These inform the Follow-the-Money doctrine and why cryptographic enforcement of
backing is essential.
