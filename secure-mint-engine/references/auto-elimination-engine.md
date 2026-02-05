# Auto-Elimination Engine

> Programmatic fail rules that automatically disqualify chains, tools, and mechanics
> from consideration in the SecureMintEngine pipeline. Eliminates human bias and
> ensures minimum quality thresholds are met.

---

## Table of Contents

1. [Overview](#overview)
2. [Chain Elimination Criteria](#chain-elimination-criteria)
3. [Tool Elimination Criteria](#tool-elimination-criteria)
4. [Mechanic Elimination Criteria](#mechanic-elimination-criteria)
5. [ELIMINATION_RULES.json Schema](#elimination_rulesjson-schema)
6. [Execution Engine](#execution-engine)
7. [Override & Appeals Process](#override--appeals-process)

---

## Overview

The Auto-Elimination Engine applies binary pass/fail checks BEFORE scoring occurs. An eliminated option is never scored, ranked, or recommended regardless of how well it performs on other dimensions.

### Principles

1. **Fail Fast**: Eliminate obvious bad choices before wasting analysis effort
2. **Binary Decisions**: Each rule is pass or fail -- no partial credit
3. **Data-Driven**: Every elimination must cite a verifiable data source
4. **Auditable**: Complete elimination log with timestamps and reasoning
5. **Overridable**: Governance can override (with justification and elevated risk tier)

### Execution Order

```
1. Load ELIMINATION_RULES.json
2. For each candidate (chain/tool/mechanic):
   a. Run ALL applicable rules
   b. Record results for each rule
   c. If ANY rule fails -> ELIMINATED
   d. If ALL rules pass -> proceed to scoring
3. Generate elimination report
```

---

## Chain Elimination Criteria

### CE-01: Minimum TVL Threshold

```yaml
rule_id: CE-01
name: Minimum TVL
category: economic
threshold: $50,000,000
condition: chain.tvl < threshold
data_source: DeFiLlama API
rationale: >
  Chains with TVL below $50M lack sufficient economic activity to support
  meaningful DeFi operations. Liquidity will be too thin for minting operations.
auto_fail: true
```

### CE-02: Oracle Provider Availability

```yaml
rule_id: CE-02
name: Oracle Provider Required
category: infrastructure
condition: >
  chain.oracle_providers does not include ("Chainlink" OR "Pyth")
data_source: Oracle provider documentation
rationale: >
  SecureMintEngine requires production-grade oracle feeds. Only Chainlink and Pyth
  meet the minimum requirements for price feed reliability and coverage.
auto_fail: true
```

### CE-03: Recent Critical Exploit

```yaml
rule_id: CE-03
name: Recent Critical Exploit
category: security
threshold_days: 30
threshold_amount: $10,000,000
condition: >
  chain.last_exploit_days < 30 AND chain.last_exploit_amount > $10M
data_source: Rekt.news, security advisories
rationale: >
  A major exploit in the last 30 days indicates active security vulnerabilities
  that have not had sufficient time to be fully analyzed and mitigated.
auto_fail: true
```

### CE-04: Chain Deprecated

```yaml
rule_id: CE-04
name: Chain Deprecated or Sunsetting
category: viability
condition: >
  chain.status IN ("deprecated", "sunsetting", "end_of_life")
  OR chain.core_team_dissolved == true
data_source: Official announcements, GitHub activity
rationale: >
  Deploying on a chain with no future is a guaranteed loss of investment.
auto_fail: true
```

### CE-05: EVM Compatibility Required

```yaml
rule_id: CE-05
name: EVM Compatibility
category: technical
condition: >
  chain.evm_compatible == false AND chain.name != "Solana"
data_source: Chain documentation
rationale: >
  Team expertise is in EVM development. Non-EVM chains (except Solana, which has
  a dedicated execution layer) require prohibitive retraining and retooling.
auto_fail: true
override_allowed: true
override_condition: "Team has demonstrated competency in target chain's language"
```

### CE-06: Regulatory Ban

```yaml
rule_id: CE-06
name: Regulatory Ban in Target Jurisdiction
category: legal
condition: >
  chain.banned_jurisdictions INTERSECTS project.target_jurisdictions
data_source: Legal counsel, regulatory databases
rationale: >
  Operating in a jurisdiction where the chain is banned exposes the project to
  legal liability and potential asset seizure.
auto_fail: true
override_allowed: false
```

### CE-07: Sequencer Centralization (Critical)

```yaml
rule_id: CE-07
name: Single Sequencer Without Decentralization Plan
category: technical
condition: >
  chain.sequencer_count == 1
  AND chain.sequencer_decentralization_plan == null
  AND chain.type == "L2"
data_source: L2Beat, chain documentation
rationale: >
  A single sequencer with no plan to decentralize creates unacceptable
  censorship and liveness risk for financial operations.
auto_fail: true
override_allowed: true
override_condition: "Chain has published decentralization roadmap with timeline"
```

### CE-08: No Block Explorer

```yaml
rule_id: CE-08
name: Block Explorer Required
category: infrastructure
condition: chain.block_explorers.count == 0
data_source: Chain documentation
rationale: >
  Contract verification and transaction monitoring are impossible without
  a block explorer. This is a non-negotiable infrastructure requirement.
auto_fail: true
```

### CE-09: Testnet Unavailable

```yaml
rule_id: CE-09
name: Testnet Required
category: infrastructure
condition: >
  chain.testnet_available == false OR chain.testnet_uptime_30d < 90%
data_source: Testnet RPC health check
rationale: >
  Cannot safely test contracts before mainnet deployment. Deploying untested
  code is not acceptable for a financial protocol.
auto_fail: true
```

### CE-10: No Audit Firm Support

```yaml
rule_id: CE-10
name: Audit Firm Availability
category: security
condition: chain.supported_audit_firms.count == 0
data_source: Audit firm surveys
rationale: >
  If no reputable audit firm can audit contracts on this chain, the protocol
  cannot meet minimum security requirements.
auto_fail: true
```

### CE-11: Bridge-Only Access (No Native Currency)

```yaml
rule_id: CE-11
name: Native Gas Token Required
category: technical
condition: >
  chain.native_token_bridges_only == true
  AND chain.native_token_liquidity < $1M
data_source: Chain documentation, DEX data
rationale: >
  If gas token can only be obtained via bridge with minimal liquidity,
  operational risk is unacceptable. Users and keepers may be unable to transact.
auto_fail: true
```

---

## Tool Elimination Criteria

### TE-01: No Audit History

```yaml
rule_id: TE-01
name: Tool Must Have Audit History
category: security
applies_to: [oracle, bridge, dex, lending_protocol]
condition: tool.audit_count == 0
data_source: Audit databases, tool documentation
rationale: >
  Any tool integrated into the minting pipeline must have at least one
  professional security audit.
auto_fail: true
```

### TE-02: Deprecated Tool

```yaml
rule_id: TE-02
name: Tool Not Deprecated
category: viability
condition: >
  tool.status == "deprecated"
  OR tool.last_update_days > 365
  OR tool.maintainer_announcement == "end_of_life"
data_source: GitHub, official channels
rationale: >
  Deprecated tools receive no security patches and may have known unfixed
  vulnerabilities.
auto_fail: true
```

### TE-03: Single Maintainer

```yaml
rule_id: TE-03
name: Tool Must Not Be Single-Maintainer
category: viability
condition: >
  tool.active_maintainers < 2
  AND tool.backed_by_organization == false
data_source: GitHub contributor analysis
rationale: >
  Single-maintainer tools have unacceptable bus factor risk. If the maintainer
  becomes unavailable, critical security patches cannot be applied.
auto_fail: true
override_allowed: true
override_condition: "Tool is backed by a funded organization with backup maintainers"
```

### TE-04: Known Unpatched Vulnerability

```yaml
rule_id: TE-04
name: No Known Unpatched Vulnerabilities
category: security
condition: tool.known_vulnerabilities.unpatched.critical > 0
data_source: CVE databases, security advisories, GitHub issues
rationale: >
  Tools with known unpatched critical vulnerabilities must not be used in
  production financial systems.
auto_fail: true
override_allowed: false
```

### TE-05: Insufficient Chain Support

```yaml
rule_id: TE-05
name: Tool Must Support Target Chain
category: technical
condition: >
  target_chain NOT IN tool.supported_chains
data_source: Tool documentation
rationale: >
  Tool must natively support the target chain. Workarounds are not acceptable
  for critical infrastructure.
auto_fail: true
```

### TE-06: License Incompatibility

```yaml
rule_id: TE-06
name: License Must Be Compatible
category: legal
condition: >
  tool.license NOT IN ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "BUSL-1.1", "GPL-2.0", "GPL-3.0"]
  OR tool.license == null
data_source: Package metadata, LICENSE file
rationale: >
  Unlicensed or incompatibly licensed dependencies create legal risk.
auto_fail: true
override_allowed: true
override_condition: "Legal counsel has approved the specific license"
```

### TE-07: Closed Source (For Security-Critical Tools)

```yaml
rule_id: TE-07
name: Security-Critical Tools Must Be Open Source
category: security
applies_to: [oracle_adapter, bridge_contract, core_dependency]
condition: tool.open_source == false
data_source: GitHub, tool documentation
rationale: >
  Security-critical components must be auditable by anyone. Closed-source
  dependencies in the minting pipeline are not acceptable.
auto_fail: true
```

---

## Mechanic Elimination Criteria

### ME-01: Chain Incompatibility

```yaml
rule_id: ME-01
name: Mechanic Must Be Compatible With Target Chain
category: technical
condition: >
  mechanic.required_features NOT SUBSET OF chain.supported_features
data_source: Chain documentation, feature matrix
rationale: >
  A mechanic that requires features not available on the target chain
  cannot be implemented safely.
auto_fail: true
examples:
  - "ERC-4626 vault on a chain without EIP-4626 support"
  - "VRF randomness on a chain without Chainlink VRF"
  - "Account abstraction on a chain without ERC-4337"
```

### ME-02: Regulatory Risk

```yaml
rule_id: ME-02
name: Mechanic Must Not Create Regulatory Risk
category: legal
condition: >
  mechanic.regulatory_classification == "securities_offering"
  AND project.has_securities_exemption == false
data_source: Legal counsel opinion
rationale: >
  Mechanics that may classify the token as a security (e.g., profit-sharing,
  revenue distribution to holders) require securities registration or exemption.
auto_fail: true
override_allowed: true
override_condition: "Legal opinion confirms the mechanic does not trigger securities classification"
```

### ME-03: Oracle-Incompatible Mechanic

```yaml
rule_id: ME-03
name: Mechanic Must Support Oracle-Gated Minting
category: technical
condition: >
  mechanic.minting_model != "oracle_gated"
  AND mechanic.requires_minting == true
  AND project.backing_type != "none"
data_source: SecureMintEngine specification
rationale: >
  SecureMintEngine requires oracle-gated minting for any backed token.
  Mechanics that bypass the oracle gate are not compatible.
auto_fail: true
override_allowed: false
```

### ME-04: Unbounded Inflation

```yaml
rule_id: ME-04
name: No Unbounded Inflation Mechanics
category: economic
condition: >
  mechanic.inflation_rate == "unbounded"
  OR mechanic.max_supply == null AND mechanic.minting == "continuous"
data_source: Mechanic specification
rationale: >
  Unbounded inflation mechanics without global caps violate INV-SM-3.
auto_fail: true
```

### ME-05: Algorithmic Stability (Without Collateral)

```yaml
rule_id: ME-05
name: No Pure Algorithmic Stability
category: economic
condition: >
  mechanic.stability_mechanism == "algorithmic"
  AND mechanic.collateral_ratio == 0
data_source: Mechanic specification
rationale: >
  Pure algorithmic stablecoins (e.g., Terra/Luna model) have a proven track
  record of catastrophic failure. SecureMintEngine requires collateral backing.
auto_fail: true
override_allowed: false
historical_evidence:
  - "Terra/Luna collapse: $40B loss, May 2022"
  - "Iron Finance: TITAN collapse to $0, June 2021"
  - "Basis Cash: Sustained depeg and abandonment, 2021"
```

### ME-06: Rebase Mechanic on Backed Token

```yaml
rule_id: ME-06
name: No Rebase on Backed Tokens
category: technical
condition: >
  mechanic.type == "rebase"
  AND project.backing_type != "none"
data_source: Mechanic specification
rationale: >
  Rebase mechanics change totalSupply without corresponding backing changes,
  violating INV-SM-1 (BackingAlwaysCoversSupply).
auto_fail: true
```

---

## ELIMINATION_RULES.json Schema

```json
{
  "$schema": "https://securemintengine.dev/schemas/elimination-rules-v1.json",
  "version": "1.0.0",
  "updated_at": "2026-01-15T00:00:00Z",

  "chain_rules": [
    {
      "rule_id": "CE-01",
      "name": "Minimum TVL",
      "category": "economic",
      "enabled": true,
      "auto_fail": true,
      "override_allowed": false,
      "condition": {
        "field": "chain.tvl_usd",
        "operator": "lt",
        "value": 50000000
      },
      "data_source": "defillama",
      "rationale": "Chains below $50M TVL lack sufficient economic activity",
      "severity": "CRITICAL"
    },
    {
      "rule_id": "CE-02",
      "name": "Oracle Provider Required",
      "category": "infrastructure",
      "enabled": true,
      "auto_fail": true,
      "override_allowed": false,
      "condition": {
        "field": "chain.oracle_providers",
        "operator": "not_intersects",
        "value": ["Chainlink", "Pyth"]
      },
      "data_source": "oracle_docs",
      "rationale": "SME requires Chainlink or Pyth for production oracle feeds",
      "severity": "CRITICAL"
    },
    {
      "rule_id": "CE-03",
      "name": "Recent Critical Exploit",
      "category": "security",
      "enabled": true,
      "auto_fail": true,
      "override_allowed": false,
      "condition": {
        "operator": "and",
        "conditions": [
          { "field": "chain.last_exploit_days", "operator": "lt", "value": 30 },
          { "field": "chain.last_exploit_amount_usd", "operator": "gt", "value": 10000000 }
        ]
      },
      "data_source": "rekt_news",
      "rationale": "Active security vulnerabilities not yet fully mitigated",
      "severity": "CRITICAL"
    }
  ],

  "tool_rules": [
    {
      "rule_id": "TE-01",
      "name": "Audit History Required",
      "category": "security",
      "enabled": true,
      "auto_fail": true,
      "override_allowed": false,
      "applies_to": ["oracle", "bridge", "dex", "lending_protocol"],
      "condition": {
        "field": "tool.audit_count",
        "operator": "eq",
        "value": 0
      },
      "data_source": "audit_databases",
      "rationale": "Unaudited tools must not be used in production minting pipeline",
      "severity": "CRITICAL"
    }
  ],

  "mechanic_rules": [
    {
      "rule_id": "ME-03",
      "name": "Oracle-Gated Minting Required",
      "category": "technical",
      "enabled": true,
      "auto_fail": true,
      "override_allowed": false,
      "condition": {
        "operator": "and",
        "conditions": [
          { "field": "mechanic.minting_model", "operator": "neq", "value": "oracle_gated" },
          { "field": "mechanic.requires_minting", "operator": "eq", "value": true },
          { "field": "project.backing_type", "operator": "neq", "value": "none" }
        ]
      },
      "data_source": "sme_specification",
      "rationale": "SecureMintEngine requires oracle-gated minting for backed tokens",
      "severity": "CRITICAL"
    },
    {
      "rule_id": "ME-05",
      "name": "No Pure Algorithmic Stability",
      "category": "economic",
      "enabled": true,
      "auto_fail": true,
      "override_allowed": false,
      "condition": {
        "operator": "and",
        "conditions": [
          { "field": "mechanic.stability_mechanism", "operator": "eq", "value": "algorithmic" },
          { "field": "mechanic.collateral_ratio", "operator": "eq", "value": 0 }
        ]
      },
      "data_source": "sme_specification",
      "rationale": "Pure algorithmic stability has proven catastrophic failure mode",
      "severity": "CRITICAL"
    }
  ],

  "operators": {
    "eq": "Equal to",
    "neq": "Not equal to",
    "lt": "Less than",
    "gt": "Greater than",
    "lte": "Less than or equal",
    "gte": "Greater than or equal",
    "in": "Value is in list",
    "not_in": "Value is not in list",
    "intersects": "Lists share at least one element",
    "not_intersects": "Lists share no elements",
    "and": "All sub-conditions must be true",
    "or": "At least one sub-condition must be true"
  }
}
```

---

## Execution Engine

### Rule Evaluator

```typescript
interface EliminationResult {
  candidate: string;
  candidate_type: "chain" | "tool" | "mechanic";
  eliminated: boolean;
  failed_rules: {
    rule_id: string;
    name: string;
    severity: string;
    details: string;
    data_source: string;
  }[];
  passed_rules: string[];
  evaluated_at: string;
}

function evaluateCandidate(
  candidate: Record<string, unknown>,
  rules: EliminationRule[],
): EliminationResult {
  const failedRules: EliminationResult["failed_rules"] = [];
  const passedRules: string[] = [];

  for (const rule of rules) {
    if (!rule.enabled) continue;

    const passes = evaluateCondition(rule.condition, candidate);
    if (!passes) {
      failedRules.push({
        rule_id: rule.rule_id,
        name: rule.name,
        severity: rule.severity,
        details: `Failed condition: ${JSON.stringify(rule.condition)}`,
        data_source: rule.data_source,
      });
    } else {
      passedRules.push(rule.rule_id);
    }
  }

  return {
    candidate: candidate.name as string,
    candidate_type: candidate.type as "chain" | "tool" | "mechanic",
    eliminated: failedRules.length > 0,
    failed_rules: failedRules,
    passed_rules: passedRules,
    evaluated_at: new Date().toISOString(),
  };
}
```

---

## Override & Appeals Process

### Override Requirements

1. **Governance proposal**: Must be submitted and approved
2. **Justification**: Written justification explaining why override is safe
3. **Risk tier elevation**: Overridden items automatically move to T3 (HIGH RISK)
4. **Time-limited**: Override expires after 90 days, must be renewed
5. **Monitoring**: Enhanced monitoring required for overridden items
6. **Audit trail**: All overrides are logged and cannot be deleted

### Override Record

```json
{
  "override_id": "OVR-2026-001",
  "rule_id": "CE-07",
  "candidate": "ExampleChain",
  "justification": "Chain has published decentralization roadmap with Q3 2026 target",
  "approved_by": ["signer1.eth", "signer2.eth", "signer3.eth"],
  "governance_proposal": "PROP-057",
  "risk_tier_override": "T3",
  "created_at": "2026-01-15T00:00:00Z",
  "expires_at": "2026-04-15T00:00:00Z",
  "monitoring_requirements": [
    "Daily sequencer uptime check",
    "Weekly decentralization progress review"
  ]
}
```
