---
name: secure-mint-launch-gates
description: God-Tier Launch Gates for SecureMintEngine. Four mandatory pre-deployment gates ensuring institutional-grade compliance, security, economics, and operational readiness. Gate 1 Legal/Regulatory, Gate 2 Security Audit Management, Gate 3 Tokenomics Stress Test, Gate 4 Launch Countdown Orchestrator. All gates must pass before production deployment.
version: 1.0.0
author: Ricardo Prieto
source: ~/.claude/commands/secure-mint-launch-gates.md
changelog:
  - 1.0.0: Initial version. 4 gates, signoff matrix, stress test scenarios.
---

# SecureMintEngine -- God-Tier Launch Gates

## Purpose

Four mandatory pre-deployment gates that ensure institutional-grade compliance, security, economics, and operational readiness. These gates run in sequence AFTER the Financial Feasibility Report is approved and BEFORE any production deployment.

**Rule: ALL four gates must pass with required signatures before deployment to mainnet.**

## Execution Triggers

```bash
make full-gates          # Run all 4 gates in sequence
make legal-gate          # Gate 1 only
make audit-gate          # Gate 2 only
make stress-test         # Gate 3 only
make launch-countdown    # Gate 4 only
```

---

## Gate Workflow Overview

```
FINANCIAL REPORT APPROVED
         |
         v
   +-------------------------------------------------------------+
   |                    GOD-TIER LAUNCH GATES                      |
   +-------------------------------------------------------------+
   |                                                               |
   |  GATE 1: Legal/Regulatory Compliance (make legal-gate)        |
   |     Howey Test, jurisdiction analysis, compliance matrix       |
   |     Required: Legal Counsel + Compliance Officer              |
   |         |                                                     |
   |         v                                                     |
   |  GATE 2: Security Audit Management (make audit-gate)          |
   |     Audit firm selection, scope, findings tracker             |
   |     Required: CTO + Security Lead + Auditor                  |
   |         |                                                     |
   |         v                                                     |
   |  GATE 3: Tokenomics Stress Test (make stress-test)            |
   |     Bank run, whale dump, death spiral simulations            |
   |     Required: Tokenomics Lead + Risk Officer                 |
   |         |                                                     |
   |         v                                                     |
   |  GATE 4: Launch Countdown Orchestrator (make launch-countdown)|
   |     T-30 to T+7 checklist, Go/No-Go decisions                |
   |     Required: CEO + CTO + Legal + Marketing                  |
   |                                                               |
   +-------------------------------------------------------------+
         |
         v
  ALL GATES PASSED -> Proceed to Deployment
```

---

## Gate 1: Legal/Regulatory Compliance

```bash
make legal-gate
```

**Generates:**
- `LEGAL_COMPLIANCE_REPORT.md` -- Comprehensive regulatory analysis
- `legal-compliance-config.json` -- Machine-readable configuration

### Howey Test Analysis

Apply the 4-prong securities classification test to the token:

| Prong | Question | Analysis | Risk Level |
|-------|----------|----------|------------|
| 1. Investment of Money | Do users exchange value (fiat, crypto) for tokens? | Document all acquisition methods | L/M/H |
| 2. Common Enterprise | Are returns pooled or tied to issuer performance? | Analyze yield distribution model | L/M/H |
| 3. Expectation of Profits | Do holders expect price appreciation or yield? | Assess marketing materials and mechanics | L/M/H |
| 4. Efforts of Others | Do profits depend on the issuer's efforts? | Evaluate decentralization degree | L/M/H |

**Classification outcomes:**
- All 4 prongs met: HIGH RISK -- likely security, requires legal opinion and potential registration
- 2-3 prongs met: MEDIUM RISK -- hybrid characteristics, obtain legal opinion
- 0-1 prongs met: LOW RISK -- likely utility token, document exemption basis

### Jurisdiction Analysis

Analyze regulatory requirements for each target jurisdiction:

| Jurisdiction | Regulator | Classification | License Required | KYC Required | Timeline | Cost |
|-------------|-----------|---------------|-----------------|-------------|----------|------|
| United States | SEC, FinCEN, State | Varies by state | MSB + State MTL | Yes (BSA) | 6-18 months | $100K-$500K |
| European Union | ESMA (MiCA) | E-money or ART | MiCA authorization | Yes (AML6D) | 6-12 months | $50K-$300K |
| United Kingdom | FCA | E-money | E-money license | Yes (MLR) | 6-12 months | $50K-$200K |
| Singapore | MAS | DPT | PSA license | Yes (PSA) | 3-6 months | $30K-$100K |
| Switzerland | FINMA | Payment token | None (self-reg) | Yes (AMLA) | 1-3 months | $20K-$80K |
| UAE | VARA/DFSA | VA | VASP license | Yes (local AML) | 3-6 months | $30K-$150K |
| Cayman Islands | CIMA | VAS | VASP registration | Yes (AML) | 2-4 months | $15K-$50K |
| China | PBOC | PROHIBITED | N/A | N/A | N/A | N/A |

### Compliance Checklist (25+ items)

**Entity Structure:**
- [ ] Legal entity formed in appropriate jurisdiction
- [ ] Registered agent appointed
- [ ] Corporate governance documents filed
- [ ] Operating agreements executed
- [ ] Bank accounts established

**Token Classification:**
- [ ] Howey Test analysis completed
- [ ] Legal opinion obtained (if needed)
- [ ] Token classified per each target jurisdiction
- [ ] Exemption basis documented
- [ ] No-action letter considered (if applicable)

**AML/KYC Requirements:**
- [ ] KYC provider selected and integrated
- [ ] AML screening service active
- [ ] Sanctions list screening (OFAC, EU, UN)
- [ ] Transaction monitoring system deployed
- [ ] Suspicious Activity Reporting (SAR) process defined
- [ ] Record retention policy (5+ years)

**Registration Filings:**
- [ ] Money Services Business (MSB) registration (US)
- [ ] State money transmitter licenses (US states)
- [ ] MiCA pre-registration (EU)
- [ ] Other jurisdictional filings as required

**Ongoing Reporting:**
- [ ] Quarterly compliance reports
- [ ] Annual audit requirements
- [ ] Regulatory change monitoring
- [ ] Incident reporting procedures

### Risk Levels

- **LOW RISK:** Utility token with clear exemptions, no yield, no profit expectation, decentralized governance
- **MEDIUM RISK:** Hybrid characteristics, some regulatory uncertainty, yield features present, partial decentralization
- **HIGH RISK:** Securities-like features, yield from reserves, centralized control, requires legal opinion before proceeding

### Required Signatures

| Role | Signature | Date |
|------|-----------|------|
| Legal Counsel | _________________ | ______ |
| Compliance Officer | _________________ | ______ |

---

## Gate 2: Security Audit Management

```bash
make audit-gate
```

**Generates:**
- `SECURITY_AUDIT_REPORT.md` -- Audit strategy and firm comparison
- `AUDIT_SCOPE_DOCUMENT.md` -- Technical scope for auditors
- `AUDIT_FINDING_TRACKER.md` -- Vulnerability tracking template

### Audit Firm Database

**Tier 1 -- Premium (recommended for mainnet launch):**

| Firm | Specialty | Timeline | Cost Range | Contact |
|------|-----------|----------|-----------|---------|
| Trail of Bits | Formal verification, low-level | 6-12 weeks | $200K-$500K | sales@trailofbits.com |
| OpenZeppelin | ERC standards, governance | 4-8 weeks | $150K-$400K | audits@openzeppelin.com |
| Consensys Diligence | DeFi, Ethereum core | 6-10 weeks | $150K-$350K | diligence@consensys.net |

**Tier 2 -- Standard (good for initial audit):**

| Firm | Specialty | Timeline | Cost Range | Contact |
|------|-----------|----------|-----------|---------|
| CertiK | Broad coverage, fast | 2-6 weeks | $50K-$200K | sales@certik.com |
| Halborn | Smart contracts, pentest | 3-6 weeks | $50K-$150K | sales@halborn.com |
| Quantstamp | Automated + manual | 4-8 weeks | $80K-$200K | sales@quantstamp.com |

**Tier 3 -- Community/Contest (supplementary):**

| Platform | Model | Timeline | Cost Range | Notes |
|----------|-------|----------|-----------|-------|
| Code4rena | Competitive contest | 1-4 weeks | $50K-$200K pool | Broad coverage |
| Sherlock | Contest + insurance | 1-3 weeks | $30K-$150K pool | Coverage included |
| Immunefi | Bug bounty (ongoing) | Ongoing | $10K-$50K/yr + payouts | Post-launch |

### Vulnerability Classification

| Severity | Definition | Examples | SLA |
|----------|-----------|----------|-----|
| CRITICAL | Direct fund theft, unlimited minting, complete system bypass | Unbacked mint, reentrancy drain, proxy hijack | Fix immediately, re-audit |
| HIGH | Significant fund loss, privilege escalation, DoS | Oracle manipulation, access control bypass, griefing | Fix before launch |
| MEDIUM | Limited impact, edge cases, conditional exploits | Gas optimization attacks, rounding errors | Fix if feasible |
| LOW | Best practices, gas optimization, code quality | Unused variables, missing events, naming | Fix in next release |
| INFORMATIONAL | Documentation, style, suggestions | NatSpec missing, test coverage gaps | Optional |

### Remediation Tracking Template

| Finding ID | Severity | Title | Status | Fix Commit | Verified | Re-test Date |
|-----------|----------|-------|--------|-----------|----------|-------------|
| AUD-001 | CRITICAL | Unbounded mint | FIXED | abc123 | YES | YYYY-MM-DD |
| AUD-002 | HIGH | Oracle bypass | FIXED | def456 | YES | YYYY-MM-DD |
| AUD-003 | MEDIUM | Gas inefficiency | ACKNOWLEDGED | N/A | N/A | N/A |

### Audit Budget Estimation

| Scope Size | Tier 1 Cost | Tier 2 Cost | Contest Cost |
|-----------|------------|------------|-------------|
| < 500 LoC | $80K-$150K | $30K-$80K | $30K-$80K |
| 500-2000 LoC | $150K-$300K | $50K-$150K | $50K-$150K |
| 2000-5000 LoC | $250K-$500K | $100K-$200K | $100K-$200K |
| > 5000 LoC | $400K+ | $150K+ | $150K+ |

**Recommended strategy:** Tier 2 initial audit + Tier 1 re-audit + Tier 3 contest post-fix.

### Audit Readiness Checklist

- [ ] Code freeze complete (no changes after submission)
- [ ] Full test coverage (> 90% line coverage)
- [ ] Documentation complete (NatSpec on all public functions)
- [ ] Known issues documented (with rationale for acceptance)
- [ ] Previous audit findings addressed (if applicable)
- [ ] Deployment scripts tested on testnet
- [ ] Access control matrix documented
- [ ] Invariant test suite passing

### Required Signatures

| Role | Signature | Date |
|------|-----------|------|
| CTO | _________________ | ______ |
| Security Lead | _________________ | ______ |
| Lead Auditor | _________________ | ______ |

---

## Gate 3: Tokenomics Stress Test

```bash
make stress-test
```

> **Python Engine:** Use local CLI for stress test data instead of loading through context:
> ```bash
> make -C ~/.claude/secure-mint-engine/assets/python-engine simulate BUNDLE=stress_scenarios.json
> make -C ~/.claude/secure-mint-engine/assets/python-engine reports-all
> make -C ~/.claude/secure-mint-engine/assets/python-engine health-check
> ```

**Generates:**
- `TOKENOMICS_STRESS_TEST.md` -- Simulation results and analysis
- `tokenomics-config.json` -- Stress test parameters

### Simulation Type 1: Bank Run Scenario

**Parameters:**
- 50% of token holders redeem simultaneously
- Treasury liquidity tiers tested in order (T0 -> T1 -> T2 -> T3)
- Redemption queue depth tested

**Pass criteria:**
- T0 + T1 cover first 30% of redemptions
- All redemptions serviced within 72 hours
- Peg deviation < 5% during event
- Protocol remains solvent throughout

**Metrics captured:** Queue depth, wait time per tier, peg deviation over time, reserve utilization rate

### Simulation Type 2: Oracle Manipulation

**Parameters:**
- +/-30% sudden price deviation attack
- Stale feed for 2+ hours
- Conflicting oracle reports (primary vs fallback)

**Pass criteria:**
- Minting blocked within 1 block of manipulation
- Circuit breaker triggers at configured threshold
- No unbacked tokens minted during attack window
- System auto-recovers when oracle normalizes

**Metrics captured:** Detection latency, false positive rate, mint blocking effectiveness, recovery time

### Simulation Type 3: Whale Dump

**Parameters:**
- Top 10 holders sell 80% of their holdings in < 1 hour
- Concentrated in 2-3 DEX pools
- Includes front-running bot simulation

**Pass criteria:**
- Peg deviation < 10% at peak
- Recovery to < 2% deviation within 4 hours
- No cascading liquidations
- Arbitrage bots restore peg naturally

**Metrics captured:** Price impact per trade, liquidity depth exhaustion, recovery timeline, slippage

### Simulation Type 4: Liquidity Crisis

**Parameters:**
- 90% of LP positions withdrawn from all DEX pools
- Cross-chain bridge liquidity drained
- Lending protocol collateral factor reduced

**Pass criteria:**
- Protocol survival (no insolvency)
- Emergency procedures activated correctly
- Communication channels operational
- Recovery plan executable within 7 days

**Metrics captured:** Remaining liquidity, swap availability, bridge functionality, lending health factor

### Simulation Type 5: Death Spiral

**Parameters:**
- Cascading liquidations triggered
- Collateral value drops 40% in 24 hours
- Holders panic-sell creating feedback loop
- Oracle deviation compounds

**Pass criteria:**
- Circuit breakers halt cascade within 3 rounds
- Collateral ratios maintained above emergency threshold
- Safety margins prevent total insolvency
- Governance can intervene before system failure

**Metrics captured:** Liquidation cascade depth, total value liquidated, min collateral ratio, time to stabilize

### Simulation Type 6: Flash Loan Attack

**Parameters:**
- Single-block manipulation using flash loan
- Attempt to manipulate oracle in same block
- Attempt to mint and dump in same transaction

**Pass criteria:**
- TWAP oracle prevents single-block manipulation
- Reentrancy guards block recursive minting
- No profitable attack path exists
- All attack transactions revert

**Metrics captured:** Attack profitability (must be negative), gas cost of attack, oracle manipulation resistance

### Output Metrics Summary

For each simulation, report:

| Metric | Value | Pass/Fail |
|--------|-------|-----------|
| Survival probability | X% | PASS if > 99% |
| Maximum drawdown | X% | PASS if < 15% |
| Recovery time estimate | X hours | PASS if < 72 hours |
| Unbacked tokens created | 0 | PASS if exactly 0 |
| Recommended mitigations | List | N/A |

### Required Signatures

| Role | Signature | Date |
|------|-----------|------|
| Tokenomics Lead | _________________ | ______ |
| Risk Officer | _________________ | ______ |

---

## Gate 4: Launch Countdown Orchestrator

```bash
make launch-countdown
```

**Generates:**
- `LAUNCH_COUNTDOWN_REPORT.md` -- Complete launch checklist
- `launch-config.json` -- Launch parameters
- `launch-checklist.json` -- Trackable checklist (machine-readable)

### Countdown Phases

#### T-30: Final Preparations (30 days before launch)

- [ ] Final audit report received and all CRITICAL/HIGH findings fixed
- [ ] Legal clearance obtained for all target jurisdictions
- [ ] Insurance policy bound (if applicable)
- [ ] Multi-sig wallets created and tested
- [ ] Deployment scripts finalized and tested on testnet
- [ ] Monitoring infrastructure deployed and alerting configured
- [ ] Incident response team identified and trained
- [ ] Communication plan finalized (PR, social, community)

#### T-14: Marketing Ramp (2 weeks before launch)

- [ ] Public announcement made
- [ ] Community AMA sessions scheduled
- [ ] Documentation site live and reviewed
- [ ] Partner integrations confirmed and tested
- [ ] Exchange listing agreements signed
- [ ] Liquidity commitments confirmed
- [ ] Press releases distributed
- [ ] Social media campaign active

#### T-7: Testnet Validation (1 week before launch)

- [ ] Full testnet deployment completed
- [ ] End-to-end testing passed (all smoke tests)
- [ ] Dry-run deployment to staging environment
- [ ] Load testing completed (expected volume * 3x)
- [ ] Security monitoring tools active on testnet
- [ ] Rollback procedure tested and documented
- [ ] Team on-call rotation confirmed

#### T-3: Final Checks (3 days before launch)

- [ ] Code freeze confirmed (no changes)
- [ ] Final security scan (Slither, Mythril)
- [ ] Oracle feeds verified and healthy
- [ ] Multi-sig signers available and responsive
- [ ] Deployer wallet funded (>= 0.5 ETH per chain)
- [ ] DNS/domain configuration verified
- [ ] API endpoints tested and healthy
- [ ] Runbook reviewed by all team members

#### T-1: Go/No-Go Decision (24 hours before launch)

- [ ] All BLOCKING items resolved
- [ ] Go/No-Go meeting held with all stakeholders
- [ ] Final risk assessment reviewed
- [ ] Weather check: no known blockchain congestion or issues
- [ ] Competitor activity assessed
- [ ] Market conditions acceptable
- [ ] ALL required signers confirmed available for next 48 hours

#### T-0: Launch Day

- [ ] Deployment transaction submitted
- [ ] Contract verification on block explorer
- [ ] Initial liquidity deposited
- [ ] Oracle feeds connected and reporting
- [ ] Monitoring dashboards live
- [ ] First mint test transaction completed
- [ ] First burn test transaction completed
- [ ] Community announcement published
- [ ] Support channels staffed

#### T+1 to T+7: Post-Launch Support

- [ ] 24/7 monitoring active for first 7 days
- [ ] Daily health reports generated
- [ ] Oracle performance tracked
- [ ] Transaction volume monitored
- [ ] Peg stability tracked (deviation < 1%)
- [ ] Bug reports triaged (4-hour SLA)
- [ ] Community feedback collected
- [ ] Post-launch retrospective scheduled (T+7)

### Go/No-Go Framework

**BLOCKING Items (must be resolved before launch):**
- Any CRITICAL audit finding unresolved
- Legal clearance not obtained
- Oracle feeds not healthy
- Multi-sig not operational
- Deployer wallet insufficient funds
- Insurance not bound (if required)
- Any invariant test failing
- Stress test showing insolvency risk

**NON-BLOCKING Items (can launch with documented risk):**
- MEDIUM/LOW audit findings outstanding
- Secondary jurisdiction licensing pending
- Non-critical monitoring gaps
- Documentation incomplete but functional
- Minor UI issues

**Decision Authority:**
- CEO has final Go/No-Go authority
- CTO can issue technical No-Go (override requires CEO + Board)
- Legal Counsel can issue regulatory No-Go (override requires Board)
- Security Lead can issue security No-Go (override requires CEO + CTO)

### Multi-Sig Coordination

**Deployment signers:**
- Minimum 3-of-5 for contract deployment
- All signers must be available for 48-hour window around launch

**Emergency pause authority:**
- 2-of-3 guardian multisig for immediate pause
- 1-of-3 for L1 pause (minting only)
- Full 3-of-5 for unpause

**Post-launch parameter changes:**
- 3-of-5 admin multisig + 48-hour timelock
- Critical changes require DAO vote + 72-hour timelock

### Required Signatures

| Role | Signature | Date |
|------|-----------|------|
| CEO / Project Lead | _________________ | ______ |
| CTO | _________________ | ______ |
| Legal Counsel | _________________ | ______ |
| Marketing Lead | _________________ | ______ |

---

## Required Signatures Summary (All Gates)

| Gate | Required Approvers | Minimum Signers |
|------|-------------------|----------------|
| Gate 1: Legal | Legal Counsel, Compliance Officer | 2 of 2 |
| Gate 2: Security | CTO, Security Lead, Auditor | 3 of 3 |
| Gate 3: Stress Test | Tokenomics Lead, Risk Officer | 2 of 2 |
| Gate 4: Launch | CEO, CTO, Legal, Marketing | 4 of 4 |

---

## Make Commands Summary

```bash
# Individual gates
make legal-gate          # Gate 1: Legal/Regulatory
make audit-gate          # Gate 2: Security Audit
make stress-test         # Gate 3: Tokenomics Stress
make launch-countdown    # Gate 4: Launch Orchestrator

# Full sequence
make full-gates          # All 4 gates in order

# Status checks
make gate-status         # Show pass/fail status of all gates
make gate-report         # Generate consolidated gate report
```

---

## Absolute Rules

1. **All 4 gates must pass.** No gate may be skipped or waived without Board-level approval.
2. **Gates run in sequence.** Gate N+1 cannot start until Gate N passes.
3. **Required signatures are mandatory.** Missing signatures block the gate.
4. **BLOCKING items are non-negotiable.** No launch with unresolved blockers.
5. **Zero tolerance for CRITICAL audit findings.** All CRITICAL findings must be fixed and re-verified.
6. **Stress tests must show zero unbacked tokens.** Any simulation producing unbacked tokens is an automatic NO-GO.
