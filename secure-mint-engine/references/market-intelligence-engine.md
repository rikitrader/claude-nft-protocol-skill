# Phase 0: Market Intelligence Engine

> Complete specification for the research and analysis engine that precedes any token
> design or deployment decision. Phase 0 produces a DECISION_CONTEXT.json that feeds
> into all subsequent phases.

---

## Table of Contents

1. [Purpose & Philosophy](#purpose--philosophy)
2. [Research Methodology](#research-methodology)
3. [Chain Comparison Criteria](#chain-comparison-criteria)
4. [Scoring Rubric](#scoring-rubric)
5. [Elimination Rules](#elimination-rules)
6. [Output Format: DECISION_CONTEXT.json](#output-format-decision_contextjson)
7. [Example Completed Analysis](#example-completed-analysis)

---

## Purpose & Philosophy

The Market Intelligence Engine ensures that every SecureMintEngine deployment is built on **neutral, production-grade research** rather than assumption, hype, or ecosystem bias.

### Core Principles

1. **Neutrality**: No chain, tool, or protocol is pre-selected. Recommendations emerge from data.
2. **Production-Grade**: Research must be current (within 30 days), cited, and verifiable.
3. **Elimination Before Selection**: Bad options removed before good options ranked.
4. **Reproducibility**: Another researcher following this methodology reaches the same conclusions.
5. **Decision Transparency**: Every recommendation includes supporting data and reasoning.

### What Phase 0 Produces

- **DECISION_CONTEXT.json**: Machine-readable context consumed by subsequent phases
- **Chain recommendation** with justification
- **Tool recommendations** (oracle, DEX, bridge, wallet)
- **Risk assessment** per option
- **Elimination log** documenting rejected options

### What Phase 0 Does NOT Do

- Does not write code
- Does not deploy contracts
- Does not make irreversible decisions
- Does not assume the user's risk tolerance

---

## Research Methodology

### Step 1: Requirement Gathering

```yaml
project_requirements:
  token_type: [stablecoin | asset_backed | synthetic | utility]
  backing_type: [on_chain_collateral | off_chain_reserve | cross_chain | hybrid]
  target_supply: [estimated initial supply]
  target_chains: [preferred chains or "any"]
  user_base: [retail | institutional | both]
  regulatory_jurisdiction: [US | EU | APAC | Global | None]
  time_to_market: [weeks]
  budget_range: [development + audit + operational]
  team_expertise: [Solidity | Rust | Both | Neither]
  existing_infrastructure: [current tech stack]
```

### Step 2: Chain Universe Enumeration

```
Tier 1 (Always Evaluate):
  - Ethereum Mainnet, Arbitrum One, Optimism, Base, Polygon PoS, Polygon zkEVM, Solana

Tier 2 (Evaluate if Requirements Match):
  - Avalanche C-Chain, BNB Chain, zkSync Era, Linea, Scroll, Mantle, Blast

Tier 3 (Evaluate Only if Explicitly Requested):
  - Fantom/Sonic, Gnosis Chain, Celo, Moonbeam, Other chains
```

### Step 3: Data Collection

For each chain, collect ALL metrics from Chain Comparison Criteria.

**Data Sources** (priority order):
1. **On-chain data**: Direct RPC queries, block explorers
2. **DeFiLlama**: TVL, protocol data, yields
3. **L2Beat**: Bridge data, risk assessments, technology
4. **Dune Analytics**: Custom queries
5. **Official documentation**: Chain docs, SDK docs
6. **Audit reports**: Infrastructure contracts
7. **GitHub**: Repository activity, contributors
8. **CoinGecko / CoinMarketCap**: Market data

### Step 4: Elimination Round

Apply Elimination Rules to remove chains that fail auto-fail conditions.

### Step 5: Scoring

Apply Scoring Rubric to remaining chains.

### Step 6: Tool Selection

For each surviving chain, evaluate oracle providers, DEX/AMM options, bridge options, wallet support.

### Step 7: Risk Assessment

Calculate risk score per option using the Risk Scoring Engine.

### Step 8: Recommendation

Compile into DECISION_CONTEXT.json with ranked recommendations, tool picks, risks, and elimination log.

---

## Chain Comparison Criteria

### 15+ Metrics Evaluated

| # | Metric | Category | Weight |
|---|--------|----------|--------|
| 1 | **Total Value Locked (TVL)** | Economic | 0.12 |
| 2 | **Daily Active Addresses** | Adoption | 0.08 |
| 3 | **Transaction Throughput (TPS)** | Technical | 0.06 |
| 4 | **Average Transaction Cost** | Economic | 0.08 |
| 5 | **Block Finality Time** | Technical | 0.07 |
| 6 | **Oracle Provider Availability** | Infrastructure | 0.12 |
| 7 | **DEX Liquidity Depth** | Economic | 0.10 |
| 8 | **Bridge Security Score** | Security | 0.08 |
| 9 | **Developer Tooling Maturity** | Technical | 0.05 |
| 10 | **Audit Infrastructure** | Security | 0.06 |
| 11 | **Regulatory Clarity** | Legal | 0.04 |
| 12 | **Time Since Last Exploit** | Security | 0.05 |
| 13 | **Sequencer/Validator Decentralization** | Technical | 0.03 |
| 14 | **EVM Compatibility** | Technical | 0.03 |
| 15 | **Ecosystem Growth Rate** | Adoption | 0.03 |

**Total Weight: 1.00**

### Metric Scoring (0-10 scale)

#### 1. Total Value Locked (TVL)
Source: DeFiLlama API (`GET https://api.llama.fi/v2/chains`)
- >= $5B: 10 | $1B-$5B: 8 | $500M-$1B: 6 | $100M-$500M: 4 | < $100M: 2

#### 2. Daily Active Addresses
Source: Block explorer / Dune Analytics
- >= 500K: 10 | 100K-500K: 8 | 50K-100K: 6 | 10K-50K: 4 | < 10K: 2

#### 3. Transaction Throughput (TPS)
Source: On-chain measurement (7-day average)
- >= 1000: 10 | 100-1000: 8 | 50-100: 6 | 15-50: 4 | < 15: 2

#### 4. Average Transaction Cost
Source: On-chain (ERC-20 transfer in USD)
- < $0.01: 10 | $0.01-$0.10: 8 | $0.10-$1.00: 6 | $1-$5: 4 | > $5: 2

#### 5. Block Finality Time
Source: Documentation + empirical
- < 2s: 10 | 2-15s: 8 | 15-60s: 6 | 1-10min: 4 | > 10min: 2

#### 6. Oracle Provider Availability
Source: Oracle documentation
- Chainlink + 2 others, 100+ feeds: 10
- Chainlink + 1 other, 50+ feeds: 8
- Chainlink only, 20+ feeds: 6
- Non-Chainlink only: 4
- No established oracle: 0 (AUTO-FAIL)

#### 7. DEX Liquidity Depth
Source: DeFiLlama DEX data
- >= $1B: 10 | $500M-$1B: 8 | $100M-$500M: 6 | $10M-$100M: 4 | < $10M: 2

#### 8. Bridge Security Score
Source: L2Beat risk analysis
- Native bridge, fully validated: 10 | Partial validation: 8
- Third-party audited: 6 | Third-party no audit: 3 | No bridge (L1): 10

#### 9. Developer Tooling Maturity
Source: GitHub, documentation
- Full Foundry + Hardhat + SDK: 10 | Foundry OR Hardhat + SDK: 8
- Custom well-documented: 6 | Minimal: 4 | None: 2

#### 10. Audit Infrastructure
Source: Audit firm availability
- 5+ major firms: 10 | 3-4: 8 | 1-2: 6 | Community only: 4 | None: 2

#### 11. Regulatory Clarity
- Clear positive: 10 | Clear neutral: 8 | Unclear no adverse: 6 | Scrutiny: 4 | Hostile: 2

#### 12. Time Since Last Exploit
Source: Rekt.news (>$1M loss)
- Never / > 2yr: 10 | 1-2yr: 8 | 6-12mo: 6 | 3-6mo: 4 | < 3mo: 2 (< 30 days: AUTO-FAIL)

#### 13-15: Additional Metrics
Similar structured scoring for decentralization, EVM compatibility, growth rate.

---

## Scoring Rubric

### Weighted Score Calculation

```
chain_score = SUM(metric_i_score * metric_i_weight) for i in 1..15
Maximum possible score: 10.0
```

### Score Interpretation

| Score Range | Classification | Recommendation |
|-------------|---------------|----------------|
| 8.5 - 10.0 | EXCELLENT | Strongly recommended |
| 7.0 - 8.4 | GOOD | Recommended with minor caveats |
| 5.5 - 6.9 | ADEQUATE | Acceptable with risk mitigations |
| 4.0 - 5.4 | MARGINAL | Not recommended without strong justification |
| 0.0 - 3.9 | POOR | Do not deploy |

### Tie-Breaking Rules

When two chains score within 0.5 points:
1. Prefer higher Oracle Provider Availability score
2. If tied, prefer higher TVL
3. If tied, prefer lower transaction cost
4. If tied, prefer team's existing experience

---

## Elimination Rules

### Auto-Fail Conditions

| Rule | Condition | Rationale |
|------|-----------|-----------|
| **E-01** | TVL < $50M | Insufficient economic activity |
| **E-02** | No Chainlink OR Pyth support | Oracle is non-negotiable |
| **E-03** | Major exploit in last 30 days (>$10M) | Active security concern |
| **E-04** | Chain deprecated or sunsetting | No future viability |
| **E-05** | No EVM compatibility (unless Solana) | Team cannot deploy |
| **E-06** | Regulatory ban in target jurisdiction | Legal risk |
| **E-07** | Single sequencer with no decentralization plan | Centralization risk |
| **E-08** | No block explorer | Cannot verify contracts |
| **E-09** | Testnet unavailable or unstable | Cannot test before deploy |
| **E-10** | No audit firm willing to audit | Cannot meet security requirements |

### Elimination Log Format

```json
{
  "eliminated": [
    {
      "chain": "ExampleChain",
      "rule": "E-03",
      "reason": "Bridge exploit on 2025-12-15, $25M lost",
      "data_source": "https://rekt.news/example-rekt/",
      "date_evaluated": "2026-01-15"
    }
  ]
}
```

---

## Output Format: DECISION_CONTEXT.json

### Complete Schema

```json
{
  "$schema": "https://securemintengine.dev/schemas/decision-context-v1.json",
  "version": "1.0.0",
  "generated_at": "ISO 8601 timestamp",
  "generated_by": "market-intelligence-engine-v1",

  "project_requirements": {
    "token_type": "stablecoin | asset_backed | synthetic | utility",
    "backing_type": "on_chain_collateral | off_chain_reserve | cross_chain | hybrid",
    "target_supply": "string",
    "target_chains": ["string"],
    "user_base": "retail | institutional | both",
    "regulatory_jurisdiction": "string",
    "time_to_market_weeks": "number",
    "budget_usd": "number",
    "team_expertise": ["Solidity", "Rust"],
    "existing_infrastructure": "string"
  },

  "chain_analysis": {
    "evaluated": [
      {
        "chain": "string",
        "chain_id": "number",
        "metrics": {
          "tvl_usd": "number",
          "tvl_score": "0-10",
          "daily_active_addresses": "number",
          "daa_score": "0-10",
          "avg_tps": "number",
          "tps_score": "0-10",
          "avg_tx_cost_usd": "number",
          "tx_cost_score": "0-10",
          "finality_seconds": "number",
          "finality_score": "0-10",
          "oracle_providers": ["string"],
          "oracle_feed_count": "number",
          "oracle_score": "0-10",
          "dex_tvl_usd": "number",
          "dex_score": "0-10",
          "bridge_risk": "string",
          "bridge_score": "0-10",
          "dev_tools": ["string"],
          "dev_tools_score": "0-10",
          "audit_firms": ["string"],
          "audit_score": "0-10",
          "regulatory_status": "string",
          "regulatory_score": "0-10",
          "last_exploit_days": "number",
          "exploit_score": "0-10",
          "sequencer_decentralization": "string",
          "sequencer_score": "0-10",
          "evm_compatible": "boolean",
          "evm_score": "0-10",
          "growth_rate_30d_pct": "number",
          "growth_score": "0-10"
        },
        "weighted_score": "0-10",
        "classification": "EXCELLENT | GOOD | ADEQUATE | MARGINAL | POOR",
        "notes": "string"
      }
    ],
    "eliminated": [
      {
        "chain": "string",
        "rule": "E-XX",
        "reason": "string",
        "data_source": "URL",
        "date_evaluated": "ISO 8601"
      }
    ],
    "recommendation": {
      "primary": "string",
      "primary_justification": "string",
      "secondary": "string",
      "secondary_justification": "string",
      "multi_chain_strategy": "string (if applicable)"
    }
  },

  "tool_analysis": {
    "oracle": {
      "recommended": "string",
      "justification": "string",
      "feeds_required": [
        {
          "pair": "ETH/USD",
          "address": "0x...",
          "heartbeat": "seconds",
          "deviation": "percentage"
        }
      ],
      "fallback": "string",
      "alternatives_evaluated": [
        { "provider": "string", "score": "number", "rejection_reason": "string" }
      ]
    },
    "dex": {
      "recommended": "string",
      "justification": "string",
      "tvl_usd": "number",
      "supported_pairs": ["string"]
    },
    "bridge": {
      "recommended": "string",
      "justification": "string",
      "security_assessment": "string"
    },
    "wallet_infra": {
      "recommended": ["string"],
      "justification": "string"
    }
  },

  "risk_assessment": {
    "overall_risk_score": "0-100",
    "risk_tier": "T1 | T2 | T3",
    "risk_factors": [
      { "factor": "string", "score": "0-100", "weight": "0-1", "details": "string" }
    ],
    "mitigations_required": [
      { "risk": "string", "mitigation": "string", "priority": "CRITICAL | HIGH | MEDIUM | LOW" }
    ]
  },

  "data_sources": [
    { "name": "string", "url": "string", "accessed_at": "ISO 8601", "data_freshness": "string" }
  ],

  "metadata": {
    "analysis_duration_hours": "number",
    "confidence_level": "HIGH | MEDIUM | LOW",
    "expiry": "ISO 8601 (30 days from generation)",
    "analyst_notes": "string"
  }
}
```

---

## Example Completed Analysis

```json
{
  "version": "1.0.0",
  "generated_at": "2026-01-15T14:30:00Z",
  "generated_by": "market-intelligence-engine-v1",

  "project_requirements": {
    "token_type": "stablecoin",
    "backing_type": "on_chain_collateral",
    "target_supply": "50M",
    "target_chains": ["any"],
    "user_base": "both",
    "regulatory_jurisdiction": "US",
    "time_to_market_weeks": 16,
    "budget_usd": 500000,
    "team_expertise": ["Solidity"],
    "existing_infrastructure": "EVM development stack"
  },

  "chain_analysis": {
    "evaluated": [
      {
        "chain": "Arbitrum One",
        "chain_id": 42161,
        "metrics": {
          "tvl_usd": 12000000000, "tvl_score": 10,
          "daily_active_addresses": 320000, "daa_score": 8,
          "avg_tps": 250, "tps_score": 8,
          "avg_tx_cost_usd": 0.05, "tx_cost_score": 8,
          "finality_seconds": 15, "finality_score": 8,
          "oracle_providers": ["Chainlink", "Pyth", "Redstone"],
          "oracle_feed_count": 200, "oracle_score": 10,
          "dex_tvl_usd": 2500000000, "dex_score": 10,
          "bridge_risk": "Stage 1 (L2Beat)", "bridge_score": 8,
          "dev_tools": ["Foundry", "Hardhat", "Arbitrum SDK"], "dev_tools_score": 10,
          "audit_firms": ["Trail of Bits", "OpenZeppelin", "Spearbit", "Cyfrin"], "audit_score": 10,
          "regulatory_status": "Unclear but no adverse action", "regulatory_score": 6,
          "last_exploit_days": 365, "exploit_score": 8,
          "sequencer_decentralization": "Single, decentralization planned", "sequencer_score": 5,
          "evm_compatible": true, "evm_score": 10,
          "growth_rate_30d_pct": 5.2, "growth_score": 8
        },
        "weighted_score": 8.68,
        "classification": "EXCELLENT",
        "notes": "Best balance of cost, speed, security, and ecosystem."
      },
      {
        "chain": "Ethereum Mainnet",
        "chain_id": 1,
        "metrics": {
          "tvl_usd": 52000000000, "tvl_score": 10,
          "daily_active_addresses": 450000, "daa_score": 8,
          "avg_tps": 15, "tps_score": 4,
          "avg_tx_cost_usd": 3.50, "tx_cost_score": 4,
          "finality_seconds": 780, "finality_score": 2,
          "oracle_providers": ["Chainlink", "Pyth", "Redstone", "API3"],
          "oracle_feed_count": 500, "oracle_score": 10,
          "dex_tvl_usd": 8500000000, "dex_score": 10,
          "bridge_risk": "N/A (L1)", "bridge_score": 10,
          "dev_tools": ["Foundry", "Hardhat", "Remix", "Tenderly"], "dev_tools_score": 10,
          "audit_firms": ["Trail of Bits", "OZ", "Consensys", "Spearbit", "Cyfrin"], "audit_score": 10,
          "regulatory_status": "Clear framework, neutral", "regulatory_score": 8,
          "last_exploit_days": 730, "exploit_score": 10,
          "sequencer_decentralization": "N/A (L1, PoS)", "sequencer_score": 10,
          "evm_compatible": true, "evm_score": 10,
          "growth_rate_30d_pct": 2.1, "growth_score": 6
        },
        "weighted_score": 8.42,
        "classification": "GOOD",
        "notes": "Highest security and liquidity but expensive. Best for large-value operations."
      }
    ],
    "eliminated": [
      {
        "chain": "Fantom",
        "rule": "E-01",
        "reason": "TVL $42M, below $50M threshold",
        "data_source": "https://defillama.com/chain/Fantom",
        "date_evaluated": "2026-01-15"
      }
    ],
    "recommendation": {
      "primary": "Arbitrum One",
      "primary_justification": "Highest weighted score (8.68). Best balance of cost, oracle support, and DeFi liquidity. Stage 1 rollup with fraud proofs live.",
      "secondary": "Ethereum Mainnet",
      "secondary_justification": "Highest security guarantees. Consider for settlement layer.",
      "multi_chain_strategy": "Deploy primary on Arbitrum with canonical bridge to Ethereum for institutional users."
    }
  },

  "tool_analysis": {
    "oracle": {
      "recommended": "Chainlink",
      "justification": "Most feeds, highest TVL secured, L2 sequencer feed, PoR capability",
      "feeds_required": [
        {"pair": "ETH/USD", "address": "0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612", "heartbeat": 3600, "deviation": 0.5},
        {"pair": "USDC/USD", "address": "0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3", "heartbeat": 86400, "deviation": 0.1},
        {"pair": "Sequencer Uptime", "address": "0xFdB631F5EE196F0ed6FAa767959853A9F217697D", "heartbeat": 0, "deviation": 0}
      ],
      "fallback": "Pyth Network",
      "alternatives_evaluated": [
        {"provider": "Pyth", "score": 8.2, "rejection_reason": "Selected as fallback"},
        {"provider": "Redstone", "score": 7.5, "rejection_reason": "Fewer feeds, less battle-tested"}
      ]
    },
    "dex": {
      "recommended": "Uniswap V3",
      "justification": "Highest liquidity on Arbitrum, concentrated liquidity, well-audited",
      "tvl_usd": 850000000,
      "supported_pairs": ["ETH/USDC", "ETH/USDT", "WBTC/ETH", "ARB/ETH"]
    },
    "bridge": {
      "recommended": "Arbitrum Native Bridge",
      "justification": "Canonical bridge with fraud proofs. 7-day challenge period.",
      "security_assessment": "Stage 1 rollup. Council can intervene but cannot censor."
    },
    "wallet_infra": {
      "recommended": ["Safe (Gnosis Safe)", "Fireblocks"],
      "justification": "Safe for on-chain multisig. Fireblocks for institutional custody."
    }
  },

  "risk_assessment": {
    "overall_risk_score": 78,
    "risk_tier": "T2",
    "risk_factors": [
      {"factor": "Sequencer centralization", "score": 60, "weight": 0.15, "details": "Single sequencer, roadmap exists"},
      {"factor": "Oracle reliability", "score": 90, "weight": 0.20, "details": "Chainlink strong on Arbitrum"},
      {"factor": "Bridge security", "score": 75, "weight": 0.15, "details": "Stage 1, council override exists"}
    ],
    "mitigations_required": [
      {"risk": "Sequencer downtime", "mitigation": "Chainlink sequencer uptime feed + grace period", "priority": "CRITICAL"},
      {"risk": "Bridge delay", "mitigation": "Fast bridge for < $100K; canonical for larger", "priority": "MEDIUM"}
    ]
  },

  "data_sources": [
    {"name": "DeFiLlama", "url": "https://defillama.com", "accessed_at": "2026-01-15T10:00:00Z", "data_freshness": "Real-time"},
    {"name": "L2Beat", "url": "https://l2beat.com", "accessed_at": "2026-01-15T10:15:00Z", "data_freshness": "Daily"},
    {"name": "Chainlink Docs", "url": "https://docs.chain.link", "accessed_at": "2026-01-15T10:30:00Z", "data_freshness": "Current"}
  ],

  "metadata": {
    "analysis_duration_hours": 4.5,
    "confidence_level": "HIGH",
    "expiry": "2026-02-14T14:30:00Z",
    "analyst_notes": "Strong recommendation for Arbitrum. Re-evaluate if sequencer has extended downtime."
  }
}
```

---

## Refreshing the Analysis

DECISION_CONTEXT.json has a 30-day expiry. Refresh before expiry if:

1. Major exploit on recommended chain
2. TVL drops > 25%
3. Oracle provider deprecates required feeds
4. Regulatory action affects recommended chain
5. Superior new chain launches

### Refresh Process

1. Re-run elimination rules
2. Update metric scores with fresh data
3. Re-calculate weighted scores
4. Update tool analysis if needed
5. Generate new DECISION_CONTEXT.json
