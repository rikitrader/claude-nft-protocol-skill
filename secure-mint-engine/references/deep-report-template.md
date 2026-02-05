# Deep Report Template

> Institutional-grade report template for blockchain protocol analysis, audits,
> risk assessments, and investment due diligence with 14 mandatory sections,
> formatting requirements, and quality standards.

---

## Table of Contents

1. [Report Structure](#report-structure)
2. [Section Specifications](#section-specifications)
3. [Data Visualization Requirements](#data-visualization-requirements)
4. [Formula Documentation Standards](#formula-documentation-standards)
5. [Audit Trail Requirements](#audit-trail-requirements)
6. [Sign-Off Template](#sign-off-template)
7. [Quality Standards](#quality-standards)

---

## Report Structure

### 14 Mandatory Sections

| # | Section | Min Words | Required Elements |
|---|---------|----------|-------------------|
| 1 | Cover Page | N/A | Title, date, classification, version, authors |
| 2 | Executive Summary | 500 | Findings, recommendations, risk rating |
| 3 | Methodology | 300 | Approach, tools, scope, limitations |
| 4 | Scope & Boundaries | 200 | In-scope, out-of-scope, assumptions |
| 5 | Market Context | 500 | Market conditions, trends, benchmarks |
| 6 | Technical Analysis | 1000 | Architecture, code review, oracle analysis |
| 7 | Risk Assessment | 800 | Risk matrix, scoring, tier classification |
| 8 | Oracle & Reserve Analysis | 600 | Oracle health, reserve verification, PoR status |
| 9 | Security Findings | 500 | Vulnerabilities, severity, remediation status |
| 10 | Economic Analysis | 600 | Tokenomics, sustainability, stress scenarios |
| 11 | Competitive Analysis | 400 | Benchmarks, differentiation, market position |
| 12 | Recommendations | 400 | Prioritized actions, timelines, owners |
| 13 | Data Appendix | N/A | Raw data, calculations, supporting evidence |
| 14 | Sign-Off & Attestation | N/A | Signatures, disclaimers, validity period |

### Document Metadata

```yaml
document:
  title: "[Protocol Name] - [Report Type]"
  subtitle: "[Analysis Period: YYYY-MM-DD to YYYY-MM-DD]"
  version: "1.0.0"
  classification: "CONFIDENTIAL | INTERNAL | PUBLIC"
  date: "YYYY-MM-DD"
  valid_until: "YYYY-MM-DD"  # 90 days from issue
  authors:
    - name: ""
      role: ""
      contact: ""
  reviewers:
    - name: ""
      role: ""
      reviewed_date: ""
  distribution:
    - "[Recipient list]"
  revision_history:
    - version: "1.0.0"
      date: "YYYY-MM-DD"
      author: ""
      changes: "Initial release"
```

---

## Section Specifications

### Section 1: Cover Page

```
+--------------------------------------------------+
|                                                    |
|  [ORGANIZATION LOGO]                              |
|                                                    |
|  DEEP ANALYSIS REPORT                             |
|                                                    |
|  [Protocol Name]                                  |
|  [Report Type: Risk Assessment / Audit /           |
|   Due Diligence / Market Analysis]                |
|                                                    |
|  Version: X.Y.Z                                   |
|  Date: YYYY-MM-DD                                 |
|  Classification: [CONFIDENTIAL/INTERNAL/PUBLIC]    |
|                                                    |
|  Prepared by: [Author Name(s)]                    |
|  Reviewed by: [Reviewer Name(s)]                  |
|                                                    |
|  [CONFIDENTIALITY NOTICE]                         |
|  This document contains proprietary information    |
|  and is intended only for the named recipients.    |
|                                                    |
+--------------------------------------------------+
```

### Section 2: Executive Summary

**Format**: Maximum 2 pages. Written for C-level audience who may read only this section.

**Required Subsections**:

#### 2.1 Overview

- One paragraph (3-5 sentences) describing the subject protocol
- Current state: TVL, users, chain(s), token type
- Launch date and maturity

#### 2.2 Key Findings

```
| # | Finding | Severity | Status | Page Ref |
|---|---------|----------|--------|----------|
| F-01 | [Description] | CRITICAL | [Open/Mitigated/Resolved] | p.___ |
| F-02 | [Description] | HIGH | [Open/Mitigated/Resolved] | p.___ |
| F-03 | [Description] | MEDIUM | [Open/Mitigated/Resolved] | p.___ |
```

#### 2.3 Risk Rating

```
Overall Risk Rating: [T1 / T2 / T3]
Composite Score: [0-100]

Breakdown:
- Technical Risk: [Score] ([T1/T2/T3])
- Market Risk: [Score] ([T1/T2/T3])
- Regulatory Risk: [Score] ([T1/T2/T3])
- Operational Risk: [Score] ([T1/T2/T3])

Key Risk Factors:
- [Factor 1]: [Score] ([weight])
- [Factor 2]: [Score] ([weight])
- [Factor 3]: [Score] ([weight])
```

#### 2.4 Recommendation Summary

```
IMMEDIATE (0-7 days):
- [Action 1] (Owner: _____, Impact: Critical)
- [Action 2] (Owner: _____, Impact: High)

SHORT-TERM (1-4 weeks):
- [Action 3] (Owner: _____, Impact: High)
- [Action 4] (Owner: _____, Impact: Medium)

MEDIUM-TERM (1-3 months):
- [Action 5] (Owner: _____, Impact: Medium)
- [Action 6] (Owner: _____, Impact: Low)
```

---

### Section 3: Methodology

**Required Content**:

1. **Approach Description**: Narrative of the analysis methodology
2. **Tools Used**: List all tools with versions
3. **Data Sources**: All external data sources with access dates
4. **Time Period**: Analysis window (start and end dates)
5. **Team**: Analysts involved and their roles
6. **Limitations**: Known gaps or constraints

**Template**:

```markdown
## Methodology

### Approach

This analysis was conducted using [methodology name] over [duration] from [start date] to [end date].
The analysis covered [scope description] and employed [approach: quantitative/qualitative/hybrid].

### Tools & Frameworks

| Tool | Version | Purpose | Output Used |
|------|---------|---------|-------------|
| Foundry | 0.2.x | Smart contract testing and analysis | Test coverage, gas reports |
| Slither | 0.10.x | Static analysis | SARIF report, finding list |
| [Tool] | [Version] | [Purpose] | [Output] |

### Data Sources

| Source | URL | Accessed | Data Period | Freshness |
|--------|-----|----------|------------|-----------|
| DeFiLlama | https://defillama.com | YYYY-MM-DD | Last 90 days | Real-time |
| CoinGecko | https://www.coingecko.com | YYYY-MM-DD | Last 365 days | Hourly updates |
| [Source] | [URL] | [Date] | [Period] | [Freshness] |

### Analysis Team

| Name | Role | Contribution |
|------|------|-------------|
| [Name] | Lead Analyst | Overall analysis, risk scoring |
| [Name] | Smart Contract Auditor | Code review, security analysis |
| [Name] | Quantitative Analyst | Financial modeling, stress testing |

### Scope

**In Scope**:
- Smart contracts: [List contracts with addresses]
- Chains: [List blockchains]
- Time period: [Date range]
- Version: [Contract version or git commit hash]

**Out of Scope**:
- Frontend application security
- Off-chain infrastructure (unless PoR-critical)
- Future roadmap items not yet deployed
- [Other exclusions with rationale]

### Limitations

1. **Data Availability**: [Limitation and impact on findings]
2. **Time Constraints**: [Limitation and impact]
3. **Access Restrictions**: [What couldn't be analyzed and why]
4. **Methodological Constraints**: [Any assumptions or simplifications]
```

---

### Section 4: Scope & Boundaries

```markdown
## Scope & Boundaries

### In Scope

| Item | Type | Version/Address | Chain |
|------|------|----------------|-------|
| SecureMintPolicy.sol | Smart Contract | 0x... | Ethereum |
| OracleRouter.sol | Smart Contract | 0x... | Ethereum |
| BackedToken.sol | Smart Contract | 0x... | Ethereum, Polygon |
| [Item] | [Type] | [Reference] | [Chain] |

### Out of Scope

| Item | Rationale |
|------|-----------|
| Frontend application | Not part of on-chain security analysis |
| Beta features (unreleased) | Not yet in production |
| [Item] | [Rationale] |

### Assumptions

1. Oracle feeds remain available and honest during analysis period
2. Underlying blockchain consensus remains secure
3. External protocol dependencies function as documented
4. [Additional assumptions]

### Constraints

1. Analysis limited to publicly available information and provided documentation
2. No access to private keys or privileged credentials
3. [Additional constraints]
```

---

### Section 5: Market Context

**Required Elements**:
- Current market conditions (bull/bear/neutral)
- Relevant market metrics (ETH price, total crypto TVL, DeFi TVL, relevant sector TVL)
- Regulatory environment update
- Competitive landscape snapshot
- Recent notable events (exploits, launches, regulatory actions)

```markdown
## Market Context

### Current Market Conditions (as of [Date])

**Macro Crypto Market**:
- Total Crypto Market Cap: $_____B
- BTC Price: $_____
- ETH Price: $_____
- Market Sentiment: [Bull / Bear / Neutral]
- Recent Trend: [Description]

**DeFi Sector**:
- Total DeFi TVL: $_____B ([±__% from last period])
- [Relevant Sector] TVL: $_____M
- Top 5 Protocols: [List with TVL]

**Relevant Events**:
- [Date]: [Event description and impact]
- [Date]: [Event description and impact]

### Regulatory Environment

- [Jurisdiction 1]: [Recent developments]
- [Jurisdiction 2]: [Recent developments]
- Impact on subject protocol: [Analysis]

### Competitive Landscape Snapshot

| Protocol | TVL | Users | YTD Growth | Risk Tier |
|----------|-----|-------|-----------|-----------|
| Subject Protocol | $___M | ___K | ___% | T_ |
| Competitor A | $___M | ___K | ___% | T_ |
| Competitor B | $___M | ___K | ___% | T_ |
```

---

### Section 6: Technical Analysis

**Required Subsections**:

```markdown
## Technical Analysis

### 6.1 Architecture Overview

[System architecture diagram or detailed description]

**Components**:
1. **Smart Contracts**: [List with purpose]
2. **Oracle Integration**: [Provider, feeds, update mechanism]
3. **Frontend**: [Technology stack]
4. **Backend/Indexer**: [Infrastructure]

**Data Flow**:
[Describe how data flows through the system, from user input to state changes]

### 6.2 Smart Contract Analysis

For each contract in scope:

#### [Contract Name] (0x...)

**Purpose**: [Description of contract's role]

**Key Metrics**:
- Lines of Code: [Count]
- Complexity Score: [Cyclomatic complexity]
- External Dependencies: [List]
- Upgrade Pattern: [Immutable / Proxy / UUPS]

**Access Control**:
| Role | Functions Accessible | Current Holders |
|------|---------------------|----------------|
| ADMIN | [Functions] | [Addresses or multisig] |
| MINTER | [Functions] | [Addresses] |
| PAUSER | [Functions] | [Addresses] |

**State Variables**:
| Variable | Type | Purpose | Mutability |
|----------|------|---------|-----------|
| [Name] | [Type] | [Purpose] | [Public/Private/Constant/Immutable] |

**Critical Functions**:
| Function | Access | Gas Cost | Risk Level |
|----------|--------|----------|-----------|
| mint() | MINTER | ___k | High |
| burn() | PUBLIC | ___k | Medium |

### 6.3 Oracle Integration Analysis

**Primary Oracle**: [Provider name]

**Configuration**:
- Feed Address: [Address per chain]
- Update Frequency (Heartbeat): [Seconds]
- Deviation Threshold: [Percentage]
- Staleness Threshold: [Max age in seconds]

**Historical Performance** (last 90 days):
- Uptime: ____%
- Maximum Staleness: _____ seconds
- Maximum Deviation: ____%
- Downtime Events: _____ (total _____ minutes)

**Fallback Configuration**:
- Secondary Oracle: [Provider if applicable]
- Fallback Logic: [Description]
- Cross-Validation: [Yes/No, threshold if yes]

**Risk Assessment**:
- [ ] Staleness checks implemented
- [ ] Deviation checks implemented
- [ ] Heartbeat monitoring
- [ ] Circuit breaker for oracle failure
- [ ] Multiple oracle sources

### 6.4 Code Quality Metrics

| Metric | Value | Benchmark | Assessment |
|--------|-------|-----------|------------|
| Test Coverage (lines) | __% | >= 95% | [Pass/Fail] |
| Test Coverage (branches) | __% | >= 90% | [Pass/Fail] |
| Slither Findings (High) | __ | 0 | [Pass/Fail] |
| Slither Findings (Medium) | __ | <= 3 | [Pass/Fail] |
| Mythril Violations | __ | 0 | [Pass/Fail] |
| Avg Gas per Mint | __ gwei | [Benchmark] | [Assessment] |
| Documentation Coverage | __% | >= 80% | [Pass/Fail] |
| Natspec Completeness | __% | >= 90% | [Pass/Fail] |

### 6.5 Dependency Analysis

| Dependency | Version | Risk | Audit Status | Notes |
|-----------|---------|------|-------------|-------|
| OpenZeppelin Contracts | v_____ | Low | Audited | [Notes] |
| Chainlink Contracts | v_____ | Low | Audited | [Notes] |
| [Dependency] | [Version] | [Risk] | [Status] | [Notes] |
```

---

### Section 7: Risk Assessment

**Required Format**: Use the Risk Scoring Engine methodology from the SecureMintEngine.

```markdown
## Risk Assessment

### 7.1 Risk Score Calculation

**Methodology**: SecureMintEngine Risk Scoring (9 metrics, weighted)

| Metric | Raw Value | Score (0-100) | Weight | Weighted Score |
|--------|----------|---------------|--------|----------------|
| Volatility (90d) | __% annualized | __ | 0.15 | __ |
| Liquidity Depth | $__M | __ | 0.12 | __ |
| Oracle Max Deviation | __% | __ | 0.15 | __ |
| TVL | $__B | __ | 0.10 | __ |
| Audit Score | [Details] | __ | 0.12 | __ |
| Exploit History | [Details] | __ | 0.15 | __ |
| ETH Correlation | __ | __ | 0.06 | __ |
| Collateral Quality | [Type] | __ | 0.10 | __ |
| Utilization Rate | __% | __ | 0.05 | __ |
| **COMPOSITE** | | | **1.00** | **__** |

### 7.2 Risk Tier: [T1 / T2 / T3]

**Tier Classification**:
- T1 (0-40): Low risk, institutional grade
- T2 (41-70): Medium risk, acceptable with monitoring
- T3 (71-100): High risk, significant concerns

**Subject Protocol Score**: __/100 = **T__**

**Peer Comparison**:
| Protocol | Composite Score | Tier |
|----------|----------------|------|
| Subject Protocol | __ | T_ |
| Similar Protocol A | __ | T_ |
| Similar Protocol B | __ | T_ |

### 7.3 Risk Matrix (Likelihood x Impact)

| Risk | Category | Likelihood | Impact | Risk Level | Mitigation | Residual Risk |
|------|---------|-----------|--------|-----------|------------|--------------|
| Smart contract exploit | Technical | M | Critical | HIGH | Multi-audit + formal verification | M |
| Oracle manipulation | Technical | L | High | MEDIUM | Deviation checks + fallback | L |
| Depeg event | Market | L | Critical | MEDIUM | Overcollateralization + pause | L |
| Regulatory action | Legal | M | High | MEDIUM | Legal counsel + compliance | M |
| [Risk] | [Category] | [H/M/L] | [H/M/L] | [Level] | [Description] | [H/M/L] |

**Risk Heat Map**:
```
           IMPACT
        L    M    H    C
L   |  L  |  L  |  M  |  M  |
I M |  L  |  M  |  H  |  H  |
K H |  M  |  H  |  H  |  C  |
```

### 7.4 Historical Incidents

| Date | Incident | Impact | Root Cause | Remediation | Recurrence Risk |
|------|----------|--------|-----------|-------------|----------------|
| [Date] | [Description] | $___M loss | [Cause] | [Actions taken] | [H/M/L] |

*None recorded* OR *[Number] incidents in last [period]*
```

---

### Section 8: Oracle & Reserve Analysis

```markdown
## Oracle & Reserve Analysis

### 8.1 Oracle Health Assessment

**Primary Feed Analysis**:

| Feed | Provider | Pair | Address | Last Update | Staleness | 90d Max Deviation | Status |
|------|---------|------|---------|------------|-----------|-------------------|--------|
| [Name] | Chainlink | BTC/USD | 0x... | [Timestamp] | __s | __% | Healthy |
| [Name] | Chainlink | ETH/USD | 0x... | [Timestamp] | __s | __% | Healthy |

**Uptime Analysis** (last 90 days):
- Days with 100% uptime: ___/90
- Maximum downtime: ___ minutes
- Average update frequency: ___ seconds
- Anomaly count: ___

**Deviation Analysis**:
- Maximum single-update deviation: ___%
- 95th percentile deviation: ___%
- Times > 1% deviation: ___

### 8.2 Reserve Verification

**Methodology**: [On-chain PoR / Off-chain attestation / Hybrid / Manual verification]

| Reserve Type | Reported Value | Verified Value | Discrepancy | Verification Method | Date Verified |
|-------------|---------------|---------------|-------------|-------------------|--------------|
| On-chain (Ethereum) | $___M | $___M | __% | Blockchain query | YYYY-MM-DD |
| Off-chain (Custodian) | $___M | $___M | __% | Attestation report | YYYY-MM-DD |
| **TOTAL** | **$___M** | **$___M** | **__%** | | |

**Reserve Ratio**: ___% (Target: >= 100%)

### 8.3 Reserve Ratio History

[Chart: Reserve ratio over time, with 100% threshold line marked]

| Date | Total Supply | Reserves | Ratio | Status |
|------|-------------|----------|-------|--------|
| [Date] | $___M | $___M | ___% | [OK/Warning/Critical] |
| [Date] | $___M | $___M | ___% | [Status] |

**Trend Analysis**: [Improving / Stable / Declining]

### 8.4 Proof-of-Reserve Feed Analysis (if applicable)

- **Feed Address**: [Address]
- **Provider**: [Chainlink / Other]
- **Last Update**: [Timestamp]
- **Reported Reserves**: [Value]
- **Total Supply (on-chain)**: [Value]
- **Calculated Ratio**: ___%
- **Historical Accuracy**: [Assessment based on spot-checks]

**Recommendations**:
- [ ] Increase update frequency
- [ ] Add secondary verification
- [ ] Implement automated alerts
- [ ] Enhance transparency reporting
```

---

### Section 9: Security Findings

**Required Format**: Each finding must include all fields below.

```markdown
## Security Findings

### Summary

| Severity | Count | % Fixed |
|----------|-------|---------|
| Critical | __ | ___% |
| High | __ | ___% |
| Medium | __ | ___% |
| Low | __ | ___% |
| Informational | __ | ___% |
| **TOTAL** | **__** | **___%** |

---

### Finding F-01: [Title]

**Severity**: CRITICAL | HIGH | MEDIUM | LOW | INFORMATIONAL
**Status**: Open | Mitigated | Resolved | Acknowledged
**Category**: [Access Control / Oracle / Reentrancy / Logic / Arithmetic / Gas / etc.]
**Location**: [File:Line or Function]
**CVSS Score**: [Score] ([Vector])

**Description**:

[Detailed description of the vulnerability or issue. Include technical details.]

**Impact**:

[What could happen if exploited. Quantify if possible ($ loss potential, user impact).]

**Proof of Concept**:

```solidity
// Exploit code or steps to reproduce
function exploit() external {
    // ...
}
```

OR

1. Step 1: [Action]
2. Step 2: [Action]
3. Result: [Outcome]

**Recommendation**:

[How to fix the issue. Provide code examples if applicable.]

```solidity
// Recommended fix
function secureFunction() external {
    // ...
}
```

**Team Response**:

> "[Response from protocol team, if available]"
> Status: [Accepted / Disputed / Acknowledged]
> Timeline: [Expected fix date]

**Verification**:

[For resolved findings: How the fix was verified]
- [ ] Code review of fix
- [ ] Re-tested exploit scenario
- [ ] Added regression test
- [ ] No new issues introduced

**References**:
- [Link to similar exploit or documentation]

---

[Repeat for each finding]

---

### Finding Distribution by Category

| Category | Critical | High | Medium | Low | Total |
|----------|---------|------|--------|-----|-------|
| Access Control | __ | __ | __ | __ | __ |
| Oracle | __ | __ | __ | __ | __ |
| Reentrancy | __ | __ | __ | __ | __ |
| Logic | __ | __ | __ | __ | __ |
| Gas Optimization | __ | __ | __ | __ | __ |
| **TOTAL** | **__** | **__** | **__** | **__** | **__** |
```

---

### Section 10: Economic Analysis

```markdown
## Economic Analysis

### 10.1 Token Supply & Distribution

**Current Supply Breakdown** (as of [Date]):

| Category | Amount | Percentage | Vesting | Circulating |
|----------|--------|-----------|---------|-------------|
| Public | ___M | ___% | Fully vested | Yes |
| Team | ___M | ___% | ___M locked | ___M |
| Investors | ___M | ___% | ___M locked | ___M |
| Treasury | ___M | ___% | Governance | Partial |
| **TOTAL** | **___M** | **100%** | | **___M** |

**Upcoming Unlocks** (next 12 months):

| Date | Category | Amount Unlocking | % of Supply |
|------|---------|-----------------|-------------|
| [Date] | [Category] | ___M | ___% |

### 10.2 Value Flows

[Diagram showing how value enters and exits the system]

**Revenue Sources**:
- Transaction fees: $___K/month
- Minting fees: $___K/month
- Other: $___K/month
- **Total**: $___K/month

**Operating Costs**:
- Development: $___K/month
- Infrastructure: $___K/month
- Marketing: $___K/month
- Other: $___K/month
- **Total**: $___K/month

**Net Cash Flow**: $___K/month ([Positive/Negative])

### 10.3 Sustainability Analysis

**Runway Analysis**:
- Current Treasury: $___M
- Monthly Burn Rate: $___K
- Runway: ___ months
- Revenue Breakeven: [Month/Year or "Achieved"]

**Long-term Sustainability**:
- Revenue Growth Rate: ___% MoM
- User Growth Rate: ___% MoM
- TVL Growth Rate: ___% MoM
- Assessment: [Sustainable / At Risk / Unsustainable]

### 10.4 Stress Scenarios

| Scenario | Assumptions | Impact on Reserves | Impact on Peg | Protocol Response | Recovery Time |
|----------|-----------|-------------------|--------------|------------------|--------------|
| ETH -50% | ETH drops from $____ to $____ | Reserve ratio: ___% → ___% | Peg: -___% | [Auto-response] | ___ days |
| Oracle failure | Primary oracle offline for ___h | Minting paused | Peg stable (no new supply) | Fallback activation | ___ hours |
| Bank run | 30% of supply redeemed in 24h | Reserves: -$___M | Possible -___% deviation | [Queue/limit mechanism] | ___ days |
| Black swan | Market -90%, all collateral affected | Reserve ratio: ___% | Depeg: -___% | Emergency shutdown | ___ weeks |

**Stress Test Results**:
- [ ] Passes all scenarios with >= 100% reserves
- [ ] Acceptable degradation (>= 90% reserves)
- [ ] Critical failures identified

### 10.5 Token Holder Distribution

| Holder Type | Count | % of Supply | Risk |
|------------|-------|------------|------|
| Top 10 holders | 10 | ___% | [Concentration risk] |
| Whales (>1% each) | __ | ___% | [Governance/liquidation risk] |
| Retail (<0.01% each) | ___K | ___% | [Decentralization benefit] |
```

---

### Section 11: Competitive Analysis

```markdown
## Competitive Analysis

### 11.1 Peer Comparison

| Metric | Subject Protocol | Competitor A | Competitor B | Competitor C | Industry Median |
|--------|----------------|-------------|-------------|-------------|----------------|
| TVL | $___M | $___M | $___M | $___M | $___M |
| Users | ___K | ___K | ___K | ___K | ___K |
| Reserve Ratio | ___% | ___% | ___% | ___% | ___% |
| Audit Count | __ | __ | __ | __ | __ |
| Oracle Provider | [Provider] | [Provider] | [Provider] | [Provider] | [Most common] |
| Launch Date | [Date] | [Date] | [Date] | [Date] | |
| Risk Tier | T_ | T_ | T_ | T_ | |
| YTD Growth | ___% | ___% | ___% | ___% | ___% |

### 11.2 Differentiation Assessment

**Strengths**:
1. [Unique advantage 1]
2. [Unique advantage 2]
3. [Unique advantage 3]

**Weaknesses**:
1. [Competitive disadvantage 1]
2. [Competitive disadvantage 2]

**Market Position**: [Leader / Challenger / Follower / Niche Player]

### 11.3 Competitive Moats

- **Technical Moat**: [Assessment]
- **Network Effect**: [Assessment]
- **Brand/Trust**: [Assessment]
- **Regulatory**: [Assessment]
- **Overall Moat Strength**: [Strong / Moderate / Weak]

### 11.4 Market Share Analysis

**Target Market Size**: $___B

| Protocol | Market Share | Trend |
|----------|-------------|-------|
| Subject Protocol | ___% | [Growing/Stable/Declining] |
| Competitor A | ___% | [Trend] |
| Competitor B | ___% | [Trend] |
```

---

### Section 12: Recommendations

```markdown
## Recommendations

### Priority 1: IMMEDIATE (0-7 days)

| # | Recommendation | Owner | Effort | Impact | Risk if Not Addressed |
|---|---------------|-------|--------|--------|---------------------|
| R-01 | [Critical action] | [Team/Role] | [S/M/L] | Critical | [Description] |
| R-02 | [Critical action] | [Team/Role] | [S/M/L] | High | [Description] |

### Priority 2: SHORT-TERM (1-4 weeks)

| # | Recommendation | Owner | Effort | Impact | Dependencies |
|---|---------------|-------|--------|--------|-------------|
| R-03 | [High-priority action] | [Team/Role] | [S/M/L] | High | [R-01, R-02] |
| R-04 | [High-priority action] | [Team/Role] | [S/M/L] | Medium | [None] |

### Priority 3: MEDIUM-TERM (1-3 months)

| # | Recommendation | Owner | Effort | Impact | Budget Estimate |
|---|---------------|-------|--------|--------|----------------|
| R-05 | [Medium-priority action] | [Team/Role] | [S/M/L] | Medium | $___K |
| R-06 | [Medium-priority action] | [Team/Role] | [S/M/L] | Low | $___K |

### Priority 4: LONG-TERM (3+ months)

| # | Recommendation | Owner | Effort | Impact | Strategic Value |
|---|---------------|-------|--------|--------|----------------|
| R-07 | [Long-term initiative] | [Team/Role] | [S/M/L] | Medium | [Description] |

### Implementation Roadmap

```
Month 1: R-01, R-02, R-03
Month 2: R-03 (complete), R-04, R-05 (start)
Month 3: R-05 (complete), R-06
Month 4-6: R-07
```

### Key Performance Indicators (Post-Implementation)

| KPI | Current | Target (3 months) | Target (6 months) |
|-----|---------|------------------|------------------|
| Risk Score | __ | __ | __ |
| Reserve Ratio | ___% | ___% | ___% |
| Critical Findings | __ | 0 | 0 |
| Oracle Uptime | ___% | >= 99.9% | >= 99.9% |
```

---

### Section 13: Data Appendix

```markdown
## Data Appendix

### A. Raw Data Tables

**Table A.1**: Daily TVL Data (Last 90 Days)
[CSV or table of daily TVL values]

**Table A.2**: Oracle Update Log (Last 30 Days)
[Timestamp, Feed, Value, Deviation data]

**Table A.3**: Transaction Volume Data
[Date, Volume, User Count, Avg Transaction Size]

### B. Calculation Details

**B.1**: Risk Score Calculation

```
Step 1: Volatility Score
  - Collected 90 daily returns
  - std_dev = 0.0342 (3.42% daily)
  - Annualized: 0.0342 * sqrt(365) = 65.34%
  - Score: map(65.34%, [0-200%], [100-0]) = 67.33

Step 2: [Next metric calculation]
  ...

Final Composite Score:
  = (67.33 * 0.15) + (45.2 * 0.12) + ... = 58.7
```

**B.2**: Reserve Ratio Verification

```
On-chain Verification (Ethereum):
- Contract: 0x...
- Function call: balanceOf(vaultAddress)
- Block: 12345678
- Timestamp: 2026-02-05 10:30:00 UTC
- Returned value: 1,234,567.89 WETH
- USD value (at $3,456.78/ETH): $4,268,901,234.56

Total Supply Verification:
- Contract: 0x...
- Function call: totalSupply()
- Returned value: 4,000,000,000 tokens
- USD value (at 1:1 peg): $4,000,000,000

Reserve Ratio = $4,268,901,234.56 / $4,000,000,000 = 106.72%
```

### C. Tool Output

**C.1**: Slither Report Summary
[Attach or excerpt key findings from Slither JSON/SARIF output]

**C.2**: Test Coverage Report
[Attach coverage report with line/branch percentages]

**C.3**: Gas Report
[Attach gas usage analysis]

### D. Oracle Feed Data

**D.1**: Historical Price Data
[CSV of timestamp, price, deviation for primary feed]

**D.2**: Uptime Log
[Downtime events with start/end timestamps]

### E. Transaction Hashes

All on-chain data referenced in this report can be verified via the following transactions:

| Reference | Transaction Hash | Block | Date |
|-----------|-----------------|-------|------|
| Reserve balance | 0x... | 12345678 | 2026-02-05 |
| Total supply | 0x... | 12345678 | 2026-02-05 |
```

---

### Section 14: Sign-Off & Attestation

[See Sign-Off Template section below]

---

## Data Visualization Requirements

### Required Charts/Visualizations

| Visualization | Section | Type | Software | Required |
|--------------|---------|------|----------|----------|
| Architecture diagram | Technical Analysis | Flowchart | Lucidchart/Draw.io | YES |
| Risk score radar chart | Risk Assessment | Radar | Excel/Python | YES |
| Reserve ratio over time | Oracle & Reserve | Line chart | Excel/Python | YES |
| TVL trend (90 days) | Market Context | Line chart | Excel/Python | YES |
| Token distribution pie chart | Economic Analysis | Pie chart | Excel/Python | YES |
| Competitive comparison | Competitive Analysis | Bar chart | Excel/Python | YES |
| Finding severity distribution | Security Findings | Bar chart | Excel/Python | YES |
| Stress scenario outcomes | Economic Analysis | Waterfall/Table | Excel | YES |

### Chart Standards

**All charts must include**:
1. Title (clear, descriptive)
2. Axis labels with units
3. Data source citation
4. Date range or "as of" date
5. Legend (if multiple series)

**Style Guidelines**:
- Font: Arial or Calibri, minimum 10pt
- Colors: Colorblind-safe palette (use ColorBrewer)
- Resolution: Minimum 150 DPI for print, SVG preferred for digital
- Data labels: Include actual values where space permits
- Gridlines: Light gray, not distracting
- Benchmark lines: Clearly marked (e.g., 100% reserve ratio threshold)

**Example Color Palette** (colorblind-safe):
- Critical/High Risk: #d73027 (red)
- Medium Risk: #fee08b (yellow)
- Low Risk: #1a9850 (green)
- Neutral: #4575b4 (blue)

---

## Formula Documentation Standards

Every calculated metric must be fully documented following this template:

```markdown
### [Metric Name]

**Formula**:
```
metric = formula_expression
```

**Variables**:
- `variable_1`: [Definition] ([Unit]) [Source: e.g., "DeFiLlama API"]
- `variable_2`: [Definition] ([Unit]) [Source]
- `variable_n`: [Definition] ([Unit]) [Source]

**Calculation** (with actual values):
```
Step 1: Obtain variable_1
  Source: [URL or method]
  Date: YYYY-MM-DD
  Raw value: [value with unit]

Step 2: Obtain variable_2
  Source: [URL or method]
  Date: YYYY-MM-DD
  Raw value: [value with unit]

Step 3: Apply formula
  metric = [formula with values substituted]
        = [intermediate result]
        = [final result with unit]
```

**Data Source Links**:
- [URL 1]: [Description]
- [URL 2]: [Description]

**Date Collected**: YYYY-MM-DD HH:MM UTC

**Notes**:
- [Any caveats, assumptions, or limitations]
- [Data transformations applied]
```

### Example: Annualized Volatility

```markdown
### Annualized Volatility

**Formula**:
```
volatility_annual = std_dev(daily_returns) * sqrt(365)
```

**Variables**:
- `daily_returns`: Array of daily percentage price changes (%) [Source: CoinGecko API]
- `365`: Days per year (constant)

**Calculation**:
```
Step 1: Collect daily price data
  Source: https://api.coingecko.com/api/v3/coins/ethereum/market_chart?days=90
  Date: 2026-02-05 14:30 UTC
  Data points: 90 daily closing prices

Step 2: Calculate daily returns
  daily_return[i] = (price[i] - price[i-1]) / price[i-1] * 100
  Resulted in 89 daily returns

Step 3: Calculate standard deviation
  std_dev(daily_returns) = 3.42% (daily)

Step 4: Annualize
  volatility_annual = 3.42% * sqrt(365)
                    = 3.42% * 19.105
                    = 65.34% (annualized)
```

**Data Source Links**:
- https://api.coingecko.com/api/v3/coins/ethereum/market_chart?vs_currency=usd&days=90&interval=daily

**Date Collected**: 2026-02-05 14:30 UTC

**Period**: 2025-11-07 to 2026-02-05 (90 days)

**Notes**:
- Used closing prices (24:00 UTC each day)
- Excludes outliers beyond 3 standard deviations
- Assumes normal distribution of returns
```

---

## Audit Trail Requirements

### Data Provenance Chain

Every data point must be traceable through this chain:

```
Raw Data Source → Collection Method → Transformation → Final Metric → Report Citation
```

**Example**:
```
CoinGecko API → Python script → stddev + annualization → 65.34% volatility → Section 7.1, Table 1
```

### Required Audit Trail Elements

For each data point used in the report:

1. **Data Provenance**: URL, API endpoint, blockchain query, or document reference
2. **Collection Timestamp**: When the data was retrieved (UTC)
3. **Collection Method**: Tool, script, manual process (provide code if scripted)
4. **Transformation Log**: Any calculations, normalization, or cleaning applied
5. **Verification**: Cross-reference with alternative source (if available)
6. **Archival**: Raw data files preserved for minimum 2 years

### Version Control

- All report drafts must be version-controlled (Git recommended)
- Each revision must include:
  - Version number (semantic versioning)
  - Date of revision
  - Author of changes
  - Changelog (what changed and why)
- Final version must be cryptographically signed

### Cryptographic Verification

**For sensitive reports**:
- Generate SHA-256 hash of final PDF
- Sign hash with PGP key
- Optionally: Store hash on blockchain for immutable timestamp
- Include verification instructions in report footer

---

## Sign-Off Template

```markdown
---

## SIGN-OFF & ATTESTATION

### Report Certification

We, the undersigned, certify that:

1. This report was prepared using the methodology described in Section 3.
2. All findings are based on data available as of [Date] and analysis conducted from [Start Date] to [End Date].
3. No material conflicts of interest exist between the analysts and the subject protocol.
4. The analysis was conducted independently and without undue influence from the subject protocol team or any other party.
5. All data sources are cited, and calculations are documented in the Data Appendix.
6. Limitations of the analysis are disclosed in Section 3.6.
7. This report represents our professional opinion based on available information.

### Signatures

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Lead Analyst | _______________ | _______________ | YYYY-MM-DD |
| Peer Reviewer | _______________ | _______________ | YYYY-MM-DD |
| Security Reviewer | _______________ | _______________ | YYYY-MM-DD |
| Approving Authority | _______________ | _______________ | YYYY-MM-DD |

### Validity Period

This report is valid for **90 days** from the date of issue:

- **Issue Date**: YYYY-MM-DD
- **Expiration Date**: YYYY-MM-DD

After the expiration date, the analysis should be refreshed to account for:
- Market condition changes
- Protocol upgrades or parameter changes
- New security disclosures or exploits
- Regulatory developments
- Material changes to competitive landscape

### Disclaimers

1. **Not Financial Advice**: This report is for informational purposes only and does not constitute financial, legal, investment, or tax advice. Recipients should consult their own advisors before making any decisions.

2. **Past Performance**: Past performance and current analysis do not guarantee future results. Blockchain protocols carry inherent risks including but not limited to smart contract vulnerabilities, oracle failures, market volatility, and regulatory changes.

3. **Best Efforts**: The analysts have made reasonable efforts to ensure accuracy and completeness but cannot guarantee that all information is correct, complete, or current. The analysis is based on publicly available information and documentation provided by the protocol team.

4. **No Warranty**: This report is provided "as is" without warranty of any kind, express or implied. The analysts disclaim all liability for any damages arising from use of this report.

5. **Supplementary Reading**: This report should be read in conjunction with the protocol's own documentation, audit reports, legal disclosures, and terms of service.

6. **Confidentiality**: Distribution of this report is subject to the classification level indicated on the cover page (see Section 14.7).

7. **Forward-Looking Statements**: Any forward-looking statements in this report are based on current expectations and are subject to risks and uncertainties.

### Classification & Distribution

| Level | Distribution | Restrictions |
|-------|-------------|-------------|
| **CONFIDENTIAL** | Named recipients only | NDA required; no redistribution without written consent |
| **INTERNAL** | Organization members only | For internal use; do not share externally |
| **PUBLIC** | Unrestricted distribution | May be shared freely; attribution required |

**This Report Classification**: [CONFIDENTIAL / INTERNAL / PUBLIC]

**Authorized Recipients**:
- [Name/Organization 1]
- [Name/Organization 2]
- [Additional recipients as specified in distribution list]

### Report Hash & Verification

For verification of report integrity, the SHA-256 hash of this report (PDF version) is:

```
[SHA-256 hash: 64-character hexadecimal string]
```

**Verification Instructions**:
1. Download the PDF version of this report
2. Calculate SHA-256 hash: `shasum -a 256 report.pdf` (macOS/Linux) or `certutil -hashfile report.pdf SHA256` (Windows)
3. Compare the calculated hash with the hash above
4. If hashes match, the document has not been altered since publication

**Optional Blockchain Attestation**:

This report hash has been recorded on-chain for immutable timestamping:

- **Transaction Hash**: [0x...]
- **Block Number**: [12345678]
- **Timestamp**: [YYYY-MM-DD HH:MM:SS UTC]
- **Blockchain**: [Ethereum Mainnet / Other]
- **Verification URL**: [Etherscan link]

### Contact Information

For questions, clarifications, or to report errors in this analysis, please contact:

**Lead Analyst**: [Name]
Email: [email]
Organization: [Organization name]
Website: [URL]

---

*End of Report*

---
```

---

## Quality Standards

### Minimum Quality Requirements

| Criterion | Requirement | Verification Method |
|----------|------------|-------------------|
| All 14 sections present | YES | Table of contents check |
| Minimum word counts met | Per section table (Section 1) | Automated word count |
| All findings properly formatted | YES | Template compliance check |
| All data sourced and dated | YES | Appendix cross-reference audit |
| All formulas documented | YES | Formula section completeness review |
| Risk score calculated correctly | YES | Independent recalculation |
| Peer reviewed | YES | Sign-off signatures present |
| Spell-checked & grammar-checked | YES | Automated tool + manual review |
| Formatting consistent | YES | Style guide compliance check |
| Charts meet standards | YES | Chart checklist (all required elements) |
| No broken links | YES | Link validation tool |
| Proper citations | YES | Reference audit |

### Review Checklist

```markdown
## Report Quality Review

Reviewer: _______________
Date: _______________

### Completeness

- [ ] All 14 sections present and populated
- [ ] Executive summary is self-contained (can be read independently)
- [ ] All critical findings appear in executive summary
- [ ] Recommendations are actionable (specify who, what, when)
- [ ] Data appendix contains all supporting data and calculations
- [ ] All tables have titles and units
- [ ] All charts have titles, labels, and sources

### Accuracy

- [ ] Risk scores independently verified by second analyst
- [ ] Formula calculations spot-checked (minimum 3 random samples)
- [ ] Data sources verified as accessible and current
- [ ] Smart contract addresses verified on blockchain explorers
- [ ] Oracle feed data cross-referenced with on-chain data
- [ ] No arithmetic errors in tables or calculations
- [ ] All percentages sum to 100% (where applicable)

### Clarity

- [ ] No undefined acronyms (define on first use)
- [ ] Technical terms explained for intended audience
- [ ] Findings clearly distinguish between confirmed and suspected issues
- [ ] Severity ratings are justified with clear criteria
- [ ] Charts are properly labeled and easy to interpret
- [ ] Report uses consistent terminology throughout
- [ ] Executive summary uses plain language (minimize jargon)

### Consistency

- [ ] Terminology consistent across all sections
- [ ] Date formats consistent (YYYY-MM-DD throughout)
- [ ] Number formats consistent (thousands separator, decimal places)
- [ ] Currency symbols consistent ($ for USD, etc.)
- [ ] Table formatting consistent (alignment, borders, shading)
- [ ] Chart color scheme consistent
- [ ] Heading levels logical and consistent
- [ ] Font sizes and styles consistent

### Compliance

- [ ] Classification level set correctly on cover page
- [ ] Classification enforced (no confidential data in public sections)
- [ ] All required disclaimers present in sign-off section
- [ ] Sign-offs obtained from all required reviewers
- [ ] Version history documented
- [ ] Distribution list accurate and complete
- [ ] Expiration date set (90 days from issue)
- [ ] Contact information current

### Professional Standards

- [ ] Report is free of spelling errors
- [ ] Report is free of grammatical errors
- [ ] Page numbers present and sequential
- [ ] Headers/footers consistent on all pages
- [ ] Report prints correctly (page breaks logical)
- [ ] PDF is searchable (OCR'd if from scanned sources)
- [ ] Hyperlinks work (both internal and external)
- [ ] Report file name follows naming convention
```

### Final QA Process

Before report release:

1. **Lead Analyst**: Self-review using checklist
2. **Peer Reviewer**: Independent review, sign-off
3. **Domain Expert**: Technical accuracy review (if applicable)
4. **Security Reviewer**: Security findings validation
5. **Legal Counsel**: Disclaimer review (for sensitive reports)
6. **Approving Authority**: Final approval and sign-off

**Minimum Review Time**: 48 hours between draft completion and final release.

---

Last Updated: 2026-02-05
