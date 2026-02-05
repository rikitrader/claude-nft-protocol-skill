---
name: secure-mint-deployment
description: Deployment and CI/CD for SecureMintEngine. Covers CI guardrail specification (monetary_routing_ci_check.py), production deployment workflow, intake CLI, preflight checks (hard and soft gates), smoke tests (SM-01 through SM-09), deployment checklist, Python Engine overview with make commands and CLI usage, and GitHub Actions pipeline specifications.
version: 1.0.0
author: Ricardo Prieto
source: ~/.claude/commands/secure-mint-deployment.md
changelog:
  - 1.0.0: Initial version. CI guardrails, preflight checks, smoke tests, Python Engine overview.
---

# SecureMintEngine -- Deployment and CI/CD

## Purpose

Provide a complete deployment pipeline from code to production, including CI guardrails that prevent misrouted monetary mechanics, preflight validation, automated smoke testing, and post-deployment verification. This command covers everything needed to safely ship SecureMintEngine contracts and infrastructure to mainnet.

**Rule: No deployment may proceed without passing all preflight hard gates, CI guardrails, and post-deployment smoke tests.**

## Execution Triggers

```bash
make production-deploy    # Full workflow: intake -> preflight -> deploy -> smoke-test
make intake              # Interactive configuration questionnaire
make preflight           # Validate all prerequisites
make deploy              # Deploy contracts to target chain
make smoke-test          # Post-deployment validation
make check               # Lint + typecheck + quick tests
make validate            # Pre-release validation
```

---

## CI Guardrail: monetary_routing_ci_check.py

### Specification

**Location:** `scripts/ci/monetary_routing_ci_check.py`

**Purpose:** Fail CI if the selected money mechanic in `intake/PROJECT_CONTEXT.json` does not match the active routing path documented in `diagrams/MonetaryRouting.ascii`.

**Reference:** `~/.claude/secure-mint-engine/scripts/`

### Routing Rules

| Rule | Condition | Required Route Marker |
|------|-----------|----------------------|
| R1 | `money_mechanic_type == "stablecoin_backed"` OR `backing_type != "none"` | `[ROUTE:SECURE_MINT]` |
| R2 | `emissions_schedule != "none"` | `[ROUTE:EMISSIONS]` |
| R3 | `cross_chain_required == true` | `[ROUTE:CROSS_CHAIN]` |
| R4 | `minting_required == false` | `[ROUTE:FIXED]` |
| R5 | `chain == "solana"` AND `token_type == "memecoin"` | `[ROUTE:MEMECOIN]` |

### CI Check Logic

```python
# Pseudocode for monetary_routing_ci_check.py

1. Load intake/PROJECT_CONTEXT.json
2. Load diagrams/MonetaryRouting.ascii
3. Determine EXPECTED route markers based on PROJECT_CONTEXT fields
4. Scan MonetaryRouting.ascii for ACTIVE route markers
5. Compare EXPECTED vs ACTIVE:
   - If match: PASS (exit 0)
   - If mismatch: FAIL (exit 1) with detailed report
6. Generate outputs/MonetaryRoutingCIReport.md
```

### Input Files

- `intake/PROJECT_CONTEXT.json` -- Token configuration with money mechanic type
- `diagrams/MonetaryRouting.ascii` -- Active routing decision tree

### Output Files

- `outputs/MonetaryRoutingCIReport.md` -- Detailed pass/fail report
- Exit code: 0 (pass) or non-zero (fail)

### CI Integration

```yaml
# .github/workflows/monetary_routing.yml
name: Monetary Routing Check
on: [push, pull_request]
jobs:
  routing-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: python3 scripts/ci/monetary_routing_ci_check.py
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: routing-report
          path: outputs/MonetaryRoutingCIReport.md
```

**If CI fails, DAO Gate MUST block deployment and require remediation.**

---

## Production Deployment Workflow

### Full Workflow

```bash
make production-deploy
```

This executes the following steps in sequence:

```
1. make intake           # Collect configuration
   |
   v
2. make preflight        # Validate prerequisites
   |
   v
3. make deploy           # Deploy contracts
   |
   v
4. make smoke-test       # Verify deployment
   |
   v
5. make verify           # Verify on block explorer
```

### Individual Make Commands

```bash
# Configuration
make intake              # Interactive configuration questionnaire
make config-validate     # Validate config.json against schema

# Pre-deployment
make preflight           # Run all preflight checks
make preflight-hard      # Hard gates only (blockers)
make preflight-soft      # Soft gates only (warnings)

# Deployment
make deploy              # Deploy all contracts
make deploy-token        # Deploy BackedToken only
make deploy-policy       # Deploy SecureMintPolicy only
make deploy-oracle       # Configure oracle adapter
make deploy-governance   # Deploy governance contracts
make deploy-emergency    # Deploy emergency pause

# Post-deployment
make smoke-test          # Run all smoke tests
make verify              # Verify contracts on explorer
make configure-roles     # Set up access control roles
make fund-treasury       # Initial treasury funding

# Utilities
make check               # Lint + typecheck + quick tests
make validate            # Full pre-release validation
make clean               # Clean build artifacts
```

---

## Intake CLI Specification

### Command

```bash
npx ts-node scripts/intake/intake-cli.ts
```

### Interactive Questions

The intake CLI collects ALL required configuration through an interactive questionnaire:

1. Token name and symbol
2. Backing type (fiat_reserves / crypto_collateral / RWA / none)
3. Target chains (multi-select)
4. Cross-chain requirement (yes/no)
5. Oracle provider preference
6. Global supply cap
7. Per-epoch mint cap
8. Epoch duration
9. Staleness threshold
10. Deviation threshold
11. Minimum collateral ratio
12. Emergency pause configuration
13. Governance model (multisig / DAO / hybrid)
14. Treasury tier allocations
15. Fee structure (mint fee, burn fee, transfer fee)

### Output Files

| File | Purpose |
|------|---------|
| `config.json` | Machine-readable full configuration |
| `RUN_PLAN.md` | Deployment steps with gates and prerequisites |
| `CHECKLIST.md` | Pre-flight and post-flight checklists |
| `TEST_PLAN.md` | Smoke tests to run after deployment |

---

## Preflight Checks

### Hard Gates (Blockers)

These must ALL pass before deployment proceeds. Any failure blocks deployment.

| Check | Command | Pass Criteria | Failure Action |
|-------|---------|---------------|---------------|
| RPC connectivity | `eth_blockNumber` | Response within 5s | Cannot deploy without RPC |
| Deployer balance | `eth_getBalance` | >= 0.5 ETH (or chain equivalent) | Fund deployer wallet |
| Oracle feed responding | Query Chainlink/Pyth | Valid response, not stale | Cannot deploy without oracle |
| Safe configuration valid | Verify multisig | All signers confirmed | Configure Safe multisig |
| Node.js version | `node --version` | >= 18.0.0 | Upgrade Node.js |
| Foundry installed | `forge --version` | Installed and accessible | Install Foundry |
| CI guardrail passes | `monetary_routing_ci_check.py` | Exit code 0 | Fix routing mismatch |
| Audit complete | Check audit report | All CRITICAL fixed | Complete audit remediation |
| Legal clearance | Check legal gate | Gate passed | Obtain legal clearance |
| Config valid | Schema validation | Valid against schema | Fix configuration |

### Soft Gates (Warnings)

These generate warnings but do not block deployment.

| Check | Command | Ideal State | Warning If |
|-------|---------|-------------|-----------|
| PostgreSQL connectivity | `pg_isready` | Connected | Not connected (optional indexer) |
| Redis connectivity | `redis-cli ping` | PONG | Not responding (optional cache) |
| Etherscan API key | Check env var | Set and valid | Missing (manual verification) |
| Tenderly API key | Check env var | Set and valid | Missing (no simulation) |
| Slack webhook | Check env var | Set and valid | Missing (no alerts) |
| Subgraph deployed | Query endpoint | Responding | Not deployed (no indexer) |
| Frontend deployed | HTTP check | 200 OK | Not deployed (CLI only) |

---

## Smoke Tests

Post-deployment validation tests. ALL must pass for deployment to be considered successful.

### SM-01: Token Deployment

```
Test: BackedToken contract is deployed and accessible
Verify: Contract address is valid, bytecode matches expected
Check: name(), symbol(), decimals() return configured values
Pass: All values match config.json
```

### SM-02: Policy Deployment

```
Test: SecureMintPolicy contract is deployed and linked to token
Verify: Policy address matches MINTER_ROLE holder on token
Check: token(), oracle(), GLOBAL_SUPPLY_CAP(), PER_EPOCH_MINT_CAP()
Pass: All references and parameters match config.json
```

### SM-03: Oracle Connectivity

```
Test: Oracle feed is responding and healthy
Verify: getBackingAmount() returns non-zero value
Check: isHealthy() returns true
Check: getLastUpdateTimestamp() is within STALENESS_THRESHOLD
Pass: Oracle is healthy and reporting current data
```

### SM-04: Token Metadata

```
Test: Token metadata is correctly configured
Verify: name() matches TOKEN_NAME from config
Verify: symbol() matches TOKEN_SYMBOL from config
Verify: decimals() matches configured decimals (default: 18)
Pass: All metadata matches
```

### SM-05: Total Supply

```
Test: Initial total supply is zero (or pre-minted amount)
Verify: totalSupply() matches expected initial supply
Check: No unexpected tokens exist
Pass: Supply matches expected initial state
```

### SM-06: Pause Level

```
Test: Emergency pause is at L0 (normal operations)
Verify: paused() returns false
Check: Pause contract is deployed and guardian multisig is set
Pass: System is operational and pause infrastructure ready
```

### SM-07: API Health

```
Test: Backend API (if deployed) is healthy
Verify: GET /health returns 200
Check: API can query contract state
Pass: API is operational
```

### SM-08: GraphQL Endpoint

```
Test: Subgraph (if deployed) is syncing
Verify: GraphQL endpoint responds
Check: Latest indexed block is within 10 blocks of head
Pass: Indexer is operational and current
```

### SM-09: Invariant Check (INV-SM-1)

```
Test: Backing covers supply (INV-SM-1)
Verify: oracle.getBackingAmount() >= token.totalSupply()
Check: Health factor >= 1.0
Pass: System is in valid state per primary invariant
```

### Smoke Test Execution

```bash
make smoke-test

# Output example:
# SM-01: Token Deployment .............. PASS
# SM-02: Policy Deployment ............. PASS
# SM-03: Oracle Connectivity ........... PASS
# SM-04: Token Metadata ................ PASS
# SM-05: Total Supply .................. PASS
# SM-06: Pause Level ................... PASS
# SM-07: API Health .................... SKIP (not deployed)
# SM-08: GraphQL Endpoint .............. SKIP (not deployed)
# SM-09: Invariant Check ............... PASS
#
# Results: 7 PASS, 0 FAIL, 2 SKIP
# Status: DEPLOYMENT VERIFIED
```

---

## Deployment Checklist

### Phase 0 Gate

- [ ] Market Intelligence Engine completed
- [ ] DECISION_CONTEXT.json approved
- [ ] Chain selection justified with weighted scores
- [ ] Tooling stack confirmed

### SecureMint Implementation

- [ ] Token contract has no discretionary mint
- [ ] Mint only callable by SecureMint policy
- [ ] Oracle staleness check implemented
- [ ] Oracle deviation bounds configured
- [ ] Global supply cap set
- [ ] Per-epoch rate limits configured
- [ ] Emergency pause implemented (4 levels)
- [ ] Pause auto-triggers on oracle failure
- [ ] Multisig controls (no EOAs)
- [ ] Timelocks on critical parameter changes

### Verification Gate

- [ ] All 4 invariants registered (INV-SM-1 through INV-SM-4)
- [ ] Threat modeling complete
- [ ] All fatal scenarios mitigated
- [ ] CI guardrail passes (monetary_routing_ci_check.py)
- [ ] Audit complete (all CRITICAL/HIGH fixed)

### DAO Gate

- [ ] Routing consistency verified (CI check)
- [ ] DECISION_CONTEXT matches implementation
- [ ] All engines integrated
- [ ] Evidence logging active

### GitHub Architecture

- [ ] Repository structure follows references/github-architecture-map.md
- [ ] Token permissions configured (Contents, PRs, Actions, Webhooks)
- [ ] Security rules enforced (no hardcoded secrets)
- [ ] CI/CD pipelines configured (GitHub Actions)
- [ ] Slither/Mythril security scanning enabled
- [ ] The Graph subgraph deployed for indexing (if applicable)
- [ ] Frontend SDK integrated (ethers.js/wagmi, if applicable)

---

## Python Engine Overview

**Location:** `~/.claude/secure-mint-engine/assets/python-engine/`

The Python Engine provides local execution for bulk operations, achieving 90-99% token reduction compared to loading contract code through context.

### Make Commands

```bash
# Setup
cd assets/python-engine
pip install -r requirements.txt
make setup

# Token Operations
make mint FILE=mint_requests.csv           # Batch mint from CSV
make mint-dry FILE=mint_requests.csv       # Dry-run (simulate only)
make burn FILE=burn_requests.csv           # Batch burn

# Compliance
make compliance ADDR=0x123...              # Single address check
make compliance FILE=addresses.txt         # Bulk compliance
make compliance-aml FILE=addresses.txt     # AML-only
make compliance-sanctions FILE=addrs.txt   # Sanctions-only

# Reports
make report TYPE=reserve                   # Reserve attestation
make report TYPE=monthly                   # Monthly compliance
make report TYPE=treasury                  # Treasury status
make report TYPE=compliance                # Full compliance
make report TYPE=bridge                    # Bridge activity
make reports-all                           # All reports

# Status
make oracle-status                         # Oracle health
make treasury-status                       # Treasury balances
make bridge-status                         # Bridge status
make invariants                            # Check all 4 invariants

# Simulation
make simulate FILE=transactions.json       # Simulate tx bundle
```

### CLI Usage

```bash
# Batch mint with validation
python securemint_cli.py mint-batch \
  -i mint_requests.csv \
  -o results.json \
  --batch-size 50 \
  --dry-run

# Compliance check
python securemint_cli.py compliance \
  -i addresses.txt \
  --kyc --aml --sanctions \
  -j US \
  -o compliance_results.json

# Generate reserve attestation
python securemint_cli.py report \
  -t reserve \
  --include-proof \
  --markdown \
  -o reports/
```

### Input Formats

**CSV (mint/burn):**
```csv
recipient,amount
0x1234...,1000000000
0x5678...,2500000000
```

**JSON (mint/burn):**
```json
{
  "requests": [
    {"recipient": "0x1234...", "amount": 1000000000},
    {"recipient": "0x5678...", "amount": 2500000000}
  ]
}
```

**Addresses (compliance):**
```
0x1234567890abcdef1234567890abcdef12345678
0xabcdef1234567890abcdef1234567890abcdef12
```

### Token Reduction Table

| Operation | Without Python Engine | With Python Engine | Reduction |
|-----------|----------------------|-------------------|-----------|
| Batch mint 1000 addresses | ~50K tokens | ~500 tokens | 99% |
| Compliance check 500 addrs | ~25K tokens | ~300 tokens | 98.8% |
| Generate all reports | ~20K tokens | ~200 tokens | 99% |
| Check invariants | ~5K tokens | ~100 tokens | 98% |

### Environment Configuration

```bash
export RPC_URL="https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"
export PRIVATE_KEY="your_private_key"    # For transactions
export TOKEN_ADDRESS="0x..."
export POLICY_ADDRESS="0x..."
export ORACLE_ADDRESS="0x..."
export TREASURY_ADDRESS="0x..."
```

---

## GitHub Actions Pipeline Specifications

### Test Pipeline

```yaml
# .github/workflows/test.yml
name: Test Suite
on: [push, pull_request]
jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: foundry-rs/foundry-toolchain@v1
      - run: forge test --match-path "test/unit/*" -vvv

  integration-tests:
    runs-on: ubuntu-latest
    needs: unit-tests
    steps:
      - uses: actions/checkout@v4
      - uses: foundry-rs/foundry-toolchain@v1
      - run: forge test --match-path "test/integration/*" -vvv

  invariant-tests:
    runs-on: ubuntu-latest
    needs: unit-tests
    steps:
      - uses: actions/checkout@v4
      - uses: foundry-rs/foundry-toolchain@v1
      - run: forge test --match-path "test/invariant/*" -vvv --fuzz-runs 1000
```

### Security Pipeline

```yaml
# .github/workflows/security.yml
name: Security Scanning
on: [push, pull_request]
jobs:
  slither:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: crytic/slither-action@v0.4.0
        with:
          slither-args: '--filter-paths "node_modules|lib"'

  mythril:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install mythril
      - run: myth analyze contracts/**/*.sol --execution-timeout 300
```

### Monetary Routing Pipeline

```yaml
# .github/workflows/monetary_routing.yml
name: Monetary Routing Check
on: [push, pull_request]
jobs:
  routing-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: python3 scripts/ci/monetary_routing_ci_check.py
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: routing-report
          path: outputs/MonetaryRoutingCIReport.md
```

### Deployment Pipeline

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  workflow_dispatch:
    inputs:
      network:
        description: 'Target network'
        required: true
        type: choice
        options: [testnet, mainnet]
      chain:
        description: 'Target chain'
        required: true
        type: choice
        options: [ethereum, arbitrum, polygon, base, optimism]

jobs:
  preflight:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make preflight

  deploy:
    runs-on: ubuntu-latest
    needs: preflight
    environment: ${{ inputs.network }}
    steps:
      - uses: actions/checkout@v4
      - uses: foundry-rs/foundry-toolchain@v1
      - run: make deploy NETWORK=${{ inputs.network }} CHAIN=${{ inputs.chain }}

  smoke-test:
    runs-on: ubuntu-latest
    needs: deploy
    steps:
      - uses: actions/checkout@v4
      - run: make smoke-test

  verify:
    runs-on: ubuntu-latest
    needs: smoke-test
    steps:
      - uses: actions/checkout@v4
      - run: make verify NETWORK=${{ inputs.network }} CHAIN=${{ inputs.chain }}
```

---

## References

- `~/.claude/secure-mint-engine/scripts/` -- CI guardrail scripts and deployment utilities
- `~/.claude/secure-mint-engine/assets/python-engine/` -- Python execution engine for bulk operations

---

## Absolute Rules

1. **CI guardrail must pass on every push.** No merge to main without routing consistency.
2. **All hard gates must pass before deployment.** No exceptions, no overrides.
3. **All smoke tests must pass after deployment.** Failed smoke tests trigger rollback investigation.
4. **No hardcoded secrets in CI/CD pipelines.** Use GitHub Secrets or environment variables.
5. **Deployment is manual-trigger only for mainnet.** No automatic mainnet deployments.
6. **Every deployment must be verified on block explorer.** Unverified contracts are a security risk.
7. **Python Engine must be used for bulk operations.** Do not load bulk data through context.
