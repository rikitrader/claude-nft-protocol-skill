---
name: secure-mint-market-intel
description: Phase 0 Market Intelligence Engine for SecureMintEngine. Performs deep neutral market research across ALL viable blockchains before any architectural decision. Generates DECISION_CONTEXT.json with chain recommendations, tooling stacks, risk exclusions, and money mechanic constraints.
version: 1.0.0
author: Ricardo Prieto
source: ~/.claude/commands/secure-mint-market-intel.md
changelog:
  - 1.0.0: Initial version. Chain evaluation, oracle/PoR provider comparison, DECISION_CONTEXT.json schema.
---

# SecureMintEngine -- Phase 0: Market Intelligence Engine

## Purpose

Perform deep, neutral, production-grade market research across ALL viable blockchains, execution environments, and tooling stacks BEFORE any architectural decision is made.

This engine prevents chain-first bias, tooling hype, incompatible money mechanics, regulatory dead-ends, and security theater.

**Rule: No downstream engine may execute until Phase 0 completes and produces an approved DECISION_CONTEXT.json.**

## Execution Trigger

```bash
make market-intel
```

Also triggered automatically by `make intake` and `make production-deploy`.

---

## Chain Comparison Methodology

### Evaluation Dimensions

Evaluate EVERY candidate chain across these 9 weighted dimensions:

| Dimension | Weight | Evaluation Criteria |
|-----------|--------|---------------------|
| Security Maturity | 0.20 | Audit history, known exploits, time in production, formal verification support |
| Oracle Infrastructure | 0.18 | Chainlink availability, TWAP options, PoR feed support, oracle redundancy |
| Stablecoin Suitability | 0.15 | Existing stablecoin TVL, regulatory precedent, redemption infrastructure |
| Developer Tooling | 0.12 | IDE support, testing frameworks, deployment tools, documentation quality |
| DeFi Composability | 0.10 | DEX liquidity depth, lending protocol presence, bridge availability |
| Cost Efficiency | 0.08 | Gas costs for mint/burn/transfer, deployment costs, oracle update costs |
| Governance Infrastructure | 0.07 | DAO tooling, timelock contracts, multisig solutions (Safe, Squads) |
| Regulatory Clarity | 0.05 | Jurisdictional stance, precedent cases, compliance tooling |
| Cross-Chain Readiness | 0.05 | Bridge security, message passing, canonical token standards |

Scoring: 0-100 per dimension. Weighted total determines tier.

- Tier 1 (score >= 80): Primary recommendation
- Tier 2 (score 65-79): Secondary / expansion target
- Tier 3 (score < 65): Not recommended without strong justification

Minimum chains to evaluate: Ethereum, Arbitrum, Polygon, Base, Solana, Avalanche, BSC, Optimism.

---

## Tooling Stack Matrix

### Oracle Providers

| Provider | Chains | PoR | TWAP | SLA | Cost |
|----------|--------|-----|------|-----|------|
| Chainlink | ETH, ARB, POLY, AVAX, BASE, OP | Yes | Yes | Heartbeat | Per-feed |
| Pyth | SOL, ETH, ARB, BASE | Limited | Yes | Pull | Free |
| Redstone | ETH, ARB, POLY | Limited | No | Pull | Per-query |
| Band | Multiple | No | Yes | Push | Per-feed |
| API3 | ETH, ARB, POLY | No | No | First-party | QRNG |
| Chronicle | ETH | No | Yes | Push | MakerDAO |

### Proof-of-Reserve Providers

| Provider | Type | Chains | Frequency | Attestation |
|----------|------|--------|-----------|-------------|
| Chainlink PoR | On-chain | ETH, ARB | Heartbeat | Oracle consensus |
| Armanino | Off-chain | Any | Daily/RT | CPA attestation |
| The Network Firm | Off-chain | Any | Monthly/Quarterly | CPA attestation |
| Custom | On-chain | Any EVM | Configurable | Multisig-submitted |

### Bridge Providers

| Bridge | Security Model | Chains | Canonical | Audits |
|--------|---------------|--------|-----------|--------|
| LayerZero (OFT) | Oracle + Relayer | 30+ | Yes | Multiple |
| Axelar (ITS) | PoS | 20+ | Yes | Multiple |
| Wormhole | Guardian network | 20+ | Yes (NTT) | Post-exploit |
| CCIP (Chainlink) | Oracle network | ETH, ARB, OP, POLY | Yes | Chainlink |
| Native bridges | L1-L2 trust | L2 specific | Yes | Chain-specific |

### Audit Firms

| Firm | Tier | Specialty | Timeline | Cost |
|------|------|-----------|----------|------|
| Trail of Bits | 1 | Formal verification | 6-12 wk | $200K-$500K |
| OpenZeppelin | 1 | ERC standards, governance | 4-8 wk | $150K-$400K |
| Consensys Diligence | 1 | DeFi protocols | 6-10 wk | $150K-$350K |
| CertiK | 2 | Broad, fast turnaround | 2-6 wk | $50K-$200K |
| Halborn | 2 | Smart contracts, pentest | 3-6 wk | $50K-$150K |
| Quantstamp | 2 | Automated + manual | 4-8 wk | $80K-$200K |
| Code4rena | 3 | Competitive contest | 1-4 wk | $50K-$200K |
| Sherlock | 3 | Contest + coverage | 1-3 wk | $30K-$150K |
| Immunefi | 3 | Bug bounty | Ongoing | $10K-$50K/yr |

---

## Money Mechanic Fit Map

| Money Mechanic | Best Chains | Acceptable | UNSAFE | Reason |
|----------------|-------------|------------|--------|--------|
| Fiat-backed (PoR) | ETH, ARB | POLY, OP, BASE | SOL, BSC | PoR oracle maturity |
| Crypto-collateral (CDP) | ETH, ARB | POLY, OP | BSC | Oracle + liquidation |
| RWA-backed | ETH | ARB, POLY | SOL, BSC | Regulatory + oracle |
| Algorithmic (pure) | NONE | NONE | ALL | Inherently fragile |
| Hybrid (partial) | ETH, ARB | POLY, OP | BSC | Robust oracle needed |
| Fixed supply | ANY | ANY | NONE | No oracle dependency |
| Emissions/rewards | ANY | ANY | NONE | Schedule-based |

**ABSOLUTE RULE: Algorithmic stablecoins with no collateral backing are ALWAYS classified as UNSAFE regardless of chain.**

---

## Risk Exclusion List

### Automatic Exclusion Criteria

| ID | Criterion | Threshold | Action |
|----|-----------|-----------|--------|
| EX-01 | Major exploit in last 6 months | Bridge or consensus level | EXCLUDE |
| EX-02 | No Chainlink/Pyth oracle support | Zero feeds | EXCLUDE for backed |
| EX-03 | TVL below threshold | < $100M | EXCLUDE |
| EX-04 | Single validator/sequencer risk | No decentralization plan | FLAG high risk |
| EX-05 | Regulatory ban in target jurisdiction | Active enforcement | EXCLUDE |
| EX-06 | No audited multisig solution | No Safe/Squads | EXCLUDE |
| EX-07 | No formal verification tooling | Zero analysis tools | FLAG high risk |
| EX-08 | Bridge-only stablecoin access | No native USDC/USDT | FLAG medium risk |
| EX-09 | Oracle update cost > 1% of mint | Gas unviable | EXCLUDE for backed |
| EX-10 | No active developer ecosystem | < 50 monthly devs | EXCLUDE |

Document each exclusion as JSON with: excluded_item, exclusion_criteria (array), evidence, override_possible, override_conditions.

---

## Chain Detection Logic

Analyze user request for chain indicators:

**Solana Route Triggers** (any match activates [ROUTE:MEMECOIN]):
- chain == "solana"
- token_type in ["memecoin", "meme", "fixed_supply"]
- Mentions: Raydium, Jupiter, pump.fun, SPL token, Anchor
- backing_type == "none" AND chain == "solana"

**EVM Route Triggers** (activates [ROUTE:SECURE_MINT] or [ROUTE:EMISSIONS]):
- chain in ["ethereum", "polygon", "arbitrum", "base", "optimism", "avalanche"]
- token_type in ["stablecoin", "backed_token", "rwa_token"]
- backing_type != "none"
- Mentions: ERC-20, Solidity, Hardhat, Foundry, Chainlink

**Ambiguous:** Ask user "Which blockchain ecosystem: Solana or EVM?"

---

## DECISION_CONTEXT.json Schema

**Output path:** `intake/DECISION_CONTEXT.json`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| schema_version | string | Yes | Schema version (e.g., "1.0.0") |
| generated_at | string | Yes | ISO-8601 timestamp |
| generated_by | string | Yes | Always "MarketIntelligenceEngine" |
| recommended_chains | array | Yes | Objects with: chain, tier (1-3), score (0-100), role (primary/secondary/expansion), rationale |
| rejected_chains | array | Yes | Objects with: chain, exclusion_criteria (EX codes), evidence, override_possible, override_conditions |
| preferred_execution_env | string | Yes | evm_solidity, solana_anchor, or multi_chain |
| preferred_oracle_stack | object | Yes | primary, fallback, por_provider, update_model, staleness_threshold, deviation_threshold |
| preferred_proof_of_reserve | object | Yes | provider, type, update_frequency, attestation_method |
| preferred_cross_chain_pattern | object | Yes | provider, security_model, canonical_chain, bridge_risk_accepted |
| money_mechanic_constraints | array | Yes | Hard constraint strings |
| security_red_lines | array | Yes | Non-negotiable security requirements |
| regulatory_red_lines | array | Yes | Non-negotiable regulatory requirements |
| tooling_dependencies | array | Yes | Objects with: tool, purpose, chain_support, criticality |
| open_unknowns | array | Yes | Objects with: question, impact, resolution_path, deadline |
| route_decision | object | Yes | route, justification, ci_marker |

---

## Execution Workflow

1. COLLECT USER REQUIREMENTS
2. ENUMERATE CANDIDATE CHAINS (minimum 6)
3. SCORE EACH CHAIN (9 dimensions, weighted)
4. APPLY EXCLUSION CRITERIA (EX-01 through EX-10)
5. BUILD TOOLING STACK MATRIX
6. MAP MONEY MECHANIC FITNESS
7. IDENTIFY OPEN UNKNOWNS
8. GENERATE DECISION_CONTEXT.json
9. PRESENT RECOMMENDATION TO USER
10. AWAIT APPROVAL BEFORE PROCEEDING

---

## Validation Rules

- [ ] At least 6 chains evaluated
- [ ] All 9 dimensions scored for every chain
- [ ] Exclusion criteria applied and documented for rejected chains
- [ ] At least 1 Tier 1 chain recommended
- [ ] Oracle stack specified with primary and fallback
- [ ] PoR provider selected (if backing_type != "none")
- [ ] Money mechanic constraints documented
- [ ] Security red lines documented (minimum 3)
- [ ] Route decision matches PROJECT_CONTEXT.json configuration
- [ ] DECISION_CONTEXT.json written and valid JSON

---

## References

- `~/.claude/secure-mint-engine/references/market-intelligence-engine.md`
- `~/.claude/secure-mint-engine/references/risk-scoring-engine.md`
- `~/.claude/secure-mint-engine/references/live-data-hooks-engine.md`
- `~/.claude/secure-mint-engine/references/auto-elimination-engine.md`

---

## Output

**Primary:** `intake/DECISION_CONTEXT.json`

**Secondary:** Chain Comparison Table, Tooling Stack Matrix, Risk Exclusion Report, Money Mechanic Fit Map

**Downstream consumers:** SecureMint Policy Contract, Business Plan Generator, Launch Gates, Deployment Pipeline

---

## Absolute Rules

1. No chain selection without scoring. Every recommendation must have a weighted score.
2. No tooling adoption without fitness evaluation. Popularity is not a criterion.
3. No downstream execution without approved DECISION_CONTEXT.json.
4. Algorithmic stablecoins without collateral are ALWAYS excluded. No exceptions.
5. Open unknowns with blocking impact must be resolved before proceeding.
