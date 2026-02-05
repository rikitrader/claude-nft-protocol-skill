# Threat Matrix for SecureMintEngine

> Comprehensive threat modeling for oracle-gated token minting systems.
> Every threat scenario includes severity rating, simulation requirements, and mitigation strategies.

---

## Table of Contents

1. [Threat Overview Dashboard](#threat-overview-dashboard)
2. [Threat Scenarios](#threat-scenarios)
3. [Attack Trees](#attack-trees)
4. [Simulation Requirements](#simulation-requirements)
5. [Incident Response Playbook Template](#incident-response-playbook-template)
6. [Red Team Checklist](#red-team-checklist)

---

## Threat Overview Dashboard

| ID | Threat | Severity | Likelihood | Impact | Risk Score |
|----|--------|----------|-----------|--------|------------|
| T-01 | Unbacked Mint | CRITICAL | Medium | Catastrophic | 9.5 |
| T-02 | Oracle Compromise | CRITICAL | Medium | Catastrophic | 9.5 |
| T-03 | Admin Key Compromise | CRITICAL | Medium | Catastrophic | 9.0 |
| T-04 | Governance Capture | HIGH | Low | Critical | 7.5 |
| T-05 | False Reserve Attestation | CRITICAL | Medium | Catastrophic | 9.0 |
| T-06 | Flash Loan Attack | HIGH | High | High | 8.0 |
| T-07 | Reentrancy Exploit | CRITICAL | Medium | Catastrophic | 9.0 |
| T-08 | Front-Running / MEV | MEDIUM | High | Medium | 6.5 |
| T-09 | Sandwich Attack | MEDIUM | High | Medium | 6.0 |
| T-10 | Bridge Exploit | CRITICAL | Medium | Catastrophic | 9.0 |
| T-11 | Price Manipulation via Low Liquidity | HIGH | High | High | 8.0 |
| T-12 | Upgrade Mechanism Abuse | CRITICAL | Low | Catastrophic | 8.0 |
| T-13 | Supply Chain Attack (Dependencies) | HIGH | Medium | High | 7.5 |
| T-14 | Denial of Service (Oracle Starvation) | MEDIUM | Medium | Medium | 5.5 |
| T-15 | Insider Threat | HIGH | Medium | Critical | 8.0 |

### Risk Scoring Formula

```
Risk Score = (Impact * 0.4) + (Likelihood * 0.3) + (Exploitability * 0.3)

Impact Scale:       1 (Negligible) to 10 (Catastrophic)
Likelihood Scale:   1 (Very Unlikely) to 10 (Very Likely)
Exploitability:     1 (Theoretical) to 10 (Script Kiddie)
```

---

## Threat Scenarios

### T-01: Unbacked Mint

**Description**: Attacker mints tokens without corresponding reserves or collateral, creating unbacked tokens that dilute value for all holders.

**Attack Vector**:
- Exploit a code path that bypasses the reserve check
- Manipulate the reserve calculation to report inflated values
- Call `_mint` directly if not properly access-controlled
- Exploit initialization/re-initialization to reset guards

**Severity**: CRITICAL | **Likelihood**: Medium | **Impact**: Catastrophic

**Mitigation**:
1. INV-SM-4 (NoBypassPath) enforced via all 5 guards on every mint
2. No `_mint` call outside the controlled `mint()` function
3. Slither custom detector for unguarded `_mint` calls
4. 100% branch coverage on mint paths in unit tests
5. Formal verification (Certora) proving no bypass exists

**Simulation**:
```
1. Deploy contracts to fork
2. Enumerate ALL public/external functions
3. Attempt to increase totalSupply from unauthorized accounts
4. Attempt to call internal _mint via delegatecall/proxy exploit
5. Fuzz all parameters on mint() to find edge cases
PASS: No totalSupply increase without all guards satisfied
```

---

### T-02: Oracle Compromise

**Description**: Attacker compromises the price oracle to report incorrect prices, enabling over-minting against inflated collateral values.

**Attack Vector**:
- Compromise oracle node operators
- Submit manipulated data to oracle network
- Deploy fake oracle contract and trick admin into switching
- Exploit oracle contract vulnerability

**Severity**: CRITICAL | **Likelihood**: Medium | **Impact**: Catastrophic

**Mitigation**:
1. Multi-oracle architecture (primary + secondary + TWAP)
2. Cross-validation: reject if primary vs secondary deviate > 5%
3. Staleness checks (INV-SM-2)
4. Circuit breaker on large price movements (> 15% in single update)
5. TWAP from on-chain DEX as sanity check
6. Oracle address change requires timelock + multisig

**Simulation**:
```
1. Mock oracle returning manipulated prices:
   a. Price = 0, b. Price = MAX_UINT256, c. Price = 2x market
   d. Stale timestamp, e. answeredInRound < roundId
2. For each: verify mint() reverts
3. Test fallback oracle activation
4. Test circuit breaker on 15%+ move
PASS: All manipulated prices blocked; fallback activates correctly
```

---

### T-03: Admin Key Compromise

**Description**: Attacker gains control of admin/owner private keys, enabling malicious parameter changes, unauthorized role grants, or contract upgrades.

**Attack Vector**:
- Phishing attack on key holders
- Compromised hardware wallet
- Stolen mnemonic/seed phrase
- Malware on admin's machine

**Severity**: CRITICAL | **Likelihood**: Medium | **Impact**: Catastrophic

**Mitigation**:
1. **Multisig requirement**: All admin operations require M-of-N (e.g., 3/5)
2. **Timelock**: 48h minimum for parameter changes, 7d for upgrades
3. **Hardware wallets**: Required for all signers
4. **Geographic distribution**: Signers in different jurisdictions
5. **Rotation**: Key rotation schedule (quarterly)
6. **Monitoring**: Alert on any admin transaction submission
7. **Emergency pause**: Separate guardian role can pause without admin

**Simulation**:
```
1. Simulate compromised admin key attempting:
   a. Grant MINTER_ROLE to attacker
   b. Change oracle address
   c. Increase epochCap to MAX_UINT256
   d. Upgrade contract
2. Verify timelock delays all operations
3. Verify multisig prevents single-key execution
4. Verify guardian can pause during timelock window
PASS: All critical operations delayed; guardian can intervene
```

---

### T-04: Governance Capture

**Description**: Attacker accumulates enough governance tokens to pass malicious proposals.

**Attack Vector**:
- Acquire majority voting power through market purchases
- Flash loan governance tokens to vote
- Bribe existing token holders
- Exploit delegation mechanics

**Severity**: HIGH | **Likelihood**: Low | **Impact**: Critical

**Mitigation**:
1. **Voting escrow**: Lock tokens for voting power (ve-model)
2. **Snapshot block**: Voting power determined before proposal
3. **Quorum requirements**: Minimum 10% of supply for critical changes
4. **Timelock**: All governance actions have execution delay
5. **Parameter bounds**: Cannot set parameters outside safe ranges
6. **Guardian veto**: Security council can veto malicious proposals

**Simulation**:
```
1. Simulate governance proposal to set reserveRatio to 0
2. Verify parameter bounds prevent unsafe values
3. Verify timelock provides intervention window
4. Verify guardian veto blocks malicious proposal
PASS: No proposal can set parameters outside safe bounds
```

---

### T-05: False Reserve Attestation

**Description**: Off-chain reserve custodian falsely reports reserves, enabling minting against phantom backing.

**Attack Vector**:
- Custodian fraud (reports reserves not held)
- Attestation provider compromise
- Man-in-the-middle on attestation feed
- Accounting manipulation (double-counting)

**Severity**: CRITICAL | **Likelihood**: Medium | **Impact**: Catastrophic

**Mitigation**:
1. **Multiple attestation providers**: Cross-reference Chainlink PoR with independent auditors
2. **Frequent attestation**: At least daily, preferably hourly
3. **Merkle proof of reserves**: Cryptographic proof of specific balances
4. **Public reserve addresses**: Allow independent verification
5. **Overcollateralization buffer**: 105% minimum
6. **Redemption testing**: Periodic automated redemption tests
7. **Insurance fund**: Reserve to cover discrepancies

**Simulation**:
```
1. Mock PoR feed reporting inflated reserves
2. Attempt to mint against false reserves
3. Verify cross-validation catches discrepancy
4. Simulate attestation going stale
5. Verify minting pauses when attestation expires
PASS: False attestation detected; minting blocked
```

---

### T-06: Flash Loan Attack

**Description**: Attacker uses flash loans to temporarily inflate collateral, mint tokens, then repay -- keeping minted tokens while removing collateral.

**Attack Vector**:
1. Flash borrow large amount of collateral asset
2. Deposit as collateral
3. Mint tokens against inflated position
4. Withdraw collateral (if same-tx allowed)
5. Repay flash loan, keep minted tokens

**Severity**: HIGH | **Likelihood**: High | **Impact**: High

**Mitigation**:
1. **Withdrawal delay**: Cannot withdraw in same block as deposit
2. **Same-block mint prevention**: `require(depositBlock[user] < block.number)`
3. **TWAP oracle**: Resists flash manipulation
4. **Minimum collateralization period**: 1 epoch before collateral counts
5. **Reentrancy guards**: Prevent re-entry during mint/burn

**Simulation**:
```
1. Execute flash loan attack on forked mainnet
2. Verify same-block deposit+mint+withdraw reverts
3. Test with Aave, dYdX, Balancer flash loans
4. Verify TWAP oracle resists price manipulation
PASS: Flash loan attack reverts at withdrawal stage
```

---

### T-07: Reentrancy Exploit

**Description**: Attacker exploits reentrancy in mint, burn, or collateral management to drain funds or double-mint.

**Attack Vector**:
- Callback during token transfer (ERC-777, hooks)
- Callback during ETH transfer in withdrawal
- Cross-function reentrancy between mint and burn
- Read-only reentrancy on view functions

**Severity**: CRITICAL | **Likelihood**: Medium | **Impact**: Catastrophic

**Mitigation**:
1. **ReentrancyGuard**: OpenZeppelin `nonReentrant` on ALL state-changing functions
2. **CEI Pattern**: Checks-Effects-Interactions strictly enforced
3. **No ETH transfers**: Use WETH to avoid receive/fallback callbacks
4. **Token whitelist**: Only allow known safe token standards
5. **Read-only reentrancy protection**: `_reentrancyGuardEntered()` in view functions

**Simulation**:
```
1. Deploy malicious token with transfer hooks
2. Attempt reentrancy on mint(), burn(), withdraw()
3. Verify ReentrancyGuard blocks all re-entries
4. Test with ERC-777 token
PASS: All reentrancy attempts revert
```

---

### T-08: Front-Running / MEV

**Description**: Searchers observe pending transactions and extract value by manipulating oracle price or front-running large operations.

**Severity**: MEDIUM | **Likelihood**: High | **Impact**: Medium

**Mitigation**:
1. Private mempool (Flashbots Protect)
2. Commit-reveal for mints
3. Batch processing at epoch boundaries
4. Slippage protection
5. Pull-based oracles (Pyth) for user-triggered updates

---

### T-09: Sandwich Attack

**Description**: Attacker sandwiches user's mint/burn to profit from price impact.

**Severity**: MEDIUM | **Likelihood**: High | **Impact**: Medium

**Mitigation**:
1. Slippage parameter on all operations
2. Private transactions (Flashbots Protect)
3. Batch auctions
4. Small transaction limits

---

### T-10: Bridge Exploit

**Description**: Bridge vulnerability creates unbacked tokens on destination chain.

**Attack Vector**:
- Bridge contract vulnerability
- Message replay for double-mint
- Bridge validator compromise
- Chain reorganization exploit

**Severity**: CRITICAL | **Likelihood**: Medium | **Impact**: Catastrophic

**Mitigation**:
1. **Canonical deployment**: Token minted on ONE chain only
2. **Lock-and-mint bridge model**
3. **Cross-chain supply cap**: Maximum bridgeable per epoch
4. **Bridge monitoring**: Real-time event monitoring
5. **Bridge selection**: Only audited bridges with insurance
6. **Rate limiting**: Maximum bridge transfer per hour/day
7. **Delayed finality**: Wait for sufficient confirmations

**Simulation**:
```
1. Simulate double-mint via message replay
2. Simulate mint without corresponding lock
3. Verify cross-chain supply cap prevents over-bridging
4. Test rate limiting blocks rapid exploitation
PASS: Cross-chain total supply never exceeds source supply
```

---

### T-11: Price Manipulation via Low Liquidity

**Description**: Attacker manipulates thinly-traded asset price to inflate collateral value.

**Severity**: HIGH | **Likelihood**: High | **Impact**: High

**Mitigation**:
1. TWAP requirement (minimum 30 min)
2. Liquidity threshold for collateral acceptance
3. Conservative LTV for less liquid assets
4. Volume filter for anomalous trading
5. Multi-source price aggregation

---

### T-12: Upgrade Mechanism Abuse

**Description**: Exploit proxy upgrade to replace logic with malicious implementation.

**Severity**: CRITICAL | **Likelihood**: Low | **Impact**: Catastrophic

**Mitigation**:
1. 7-day timelock on upgrades
2. Multi-sig requirement
3. Automated invariant checks on new implementation
4. Storage layout validation
5. Consider non-upgradeable contracts

---

### T-13: Supply Chain Attack (Dependencies)

**Description**: Compromised npm/foundry dependency introduces backdoor.

**Severity**: HIGH | **Likelihood**: Medium | **Impact**: High

**Mitigation**:
1. Pin all dependencies to exact versions
2. Commit lock files
3. Review all dependency changes
4. Minimal dependencies
5. Build reproducibility verification
6. Source verification on Etherscan/Sourcify

---

### T-14: Denial of Service (Oracle Starvation)

**Description**: Attacker prevents oracle updates, causing indefinite system pause.

**Severity**: MEDIUM | **Likelihood**: Medium | **Impact**: Medium

**Mitigation**:
1. Multiple oracle sources with different update mechanisms
2. Extended staleness for reduced minting
3. Keeper redundancy
4. Pre-funded gas reserves
5. L2 deployment (lower gas costs)

---

### T-15: Insider Threat

**Description**: Team member with privileged access acts maliciously.

**Severity**: HIGH | **Likelihood**: Medium | **Impact**: Critical

**Mitigation**:
1. Multisig for all critical operations
2. Mandatory code review (2+ approvals)
3. Immutable audit trail
4. Separation of duties
5. Time-delayed operations
6. Bug bounty program

---

## Attack Trees

### Master Attack Tree: Mint Unbacked Tokens

```
GOAL: Mint tokens without backing
+-- Bypass oracle check
|   +-- Compromise oracle (T-02)
|   +-- Manipulate price on low-liquidity market (T-11)
|   +-- Exploit stale price window (T-02)
|   +-- Deploy fake oracle + admin key compromise (T-02 + T-03)
+-- Bypass reserve check
|   +-- False reserve attestation (T-05)
|   +-- Flash loan to inflate reserves (T-06)
|   +-- Exploit reserve calculation bug (T-01)
+-- Bypass access control
|   +-- Admin key compromise (T-03)
|   +-- Governance capture (T-04)
|   +-- Exploit unguarded mint path (T-01)
|   +-- Upgrade to malicious implementation (T-12)
+-- Bypass rate limits
|   +-- Exploit epoch boundary
|   +-- Governance to increase caps (T-04)
|   +-- Exploit overflow in cap calculation (T-01)
+-- Cross-chain attack
    +-- Bridge exploit to mint on destination (T-10)
    +-- Chain reorg to revert burn but keep mint
```

---

## Simulation Requirements

### Required Tools

| Tool | Purpose | Required For |
|------|---------|-------------|
| Foundry | Invariant testing, fuzzing | All simulations |
| Slither | Static analysis | T-01, T-07, T-12 |
| Mythril | Symbolic execution | T-01, T-04 |
| Echidna | Property-based testing | All invariants |
| Medusa | Parallel fuzzing | Performance-critical tests |
| Tenderly | Transaction simulation | T-06, T-08, T-09 |
| Certora | Formal verification | T-04 (NoBypassPath) |

### Minimum Coverage

| Category | Requirement |
|----------|------------|
| Unit tests | 100% line + branch coverage on mint/burn/oracle |
| Fuzz tests | 10,000 runs minimum per invariant |
| Invariant tests | All 7 invariants, 1000 sequences, 200 depth |
| Integration tests | Fork tests against live oracle data |
| Static analysis | Zero high/critical findings from Slither |
| Symbolic execution | Zero violations from Mythril (depth 20) |

---

## Incident Response Playbook Template

### Playbook Header

```yaml
incident_id: INC-YYYY-MM-DD-NNN
severity: CRITICAL | HIGH | MEDIUM | LOW
threat_id: T-XX
status: DETECTED | INVESTIGATING | MITIGATING | RESOLVED | POST-MORTEM
commander: <name>
created: <timestamp>
updated: <timestamp>
```

### Phase 1: Detection (0-5 min)

- [ ] Alert received from monitoring system
- [ ] Initial assessment: affected contracts, chains, estimated exposure
- [ ] Incident commander assigned
- [ ] Communication channel opened

### Phase 2: Containment (5-30 min)

- [ ] Emergency pause executed (tx hash recorded)
- [ ] Verified pause is effective (mint/burn/bridge blocked)
- [ ] Evidence preserved (tx logs, state snapshots, mempool data)
- [ ] Security team, engineering lead, legal team notified

### Phase 3: Investigation (30 min - 4 hours)

- [ ] Root cause identified
- [ ] Attack vector mapped to threat matrix (T-XX)
- [ ] Attacker address(es) identified
- [ ] Funds at risk / funds lost quantified
- [ ] Affected users counted
- [ ] Timeline of attack documented

### Phase 4: Remediation (4-48 hours)

- [ ] Fix developed and reviewed
- [ ] Fix tested (unit, fork, invariant)
- [ ] Deployment plan with timelock/multisig
- [ ] System un-paused after verification
- [ ] Enhanced monitoring deployed

### Phase 5: Recovery (48h - 2 weeks)

- [ ] Affected users compensated
- [ ] Insurance claim filed
- [ ] Public disclosure published
- [ ] Post-mortem completed
- [ ] Process improvements implemented
- [ ] Additional audit scheduled

### Post-Mortem Template

```markdown
## Summary
[2-3 sentence summary]

## Timeline
[Detailed chronological events]

## Root Cause
[Technical description]

## Impact
- Financial: [$amount]
- Users affected: [count]
- Downtime: [duration]

## What Went Well
- [Item]

## What Went Poorly
- [Item]

## Action Items
| Action | Owner | Due Date | Status |
|--------|-------|----------|--------|
```

---

## Red Team Checklist

### Contract Security
- [ ] All mint paths require 5 guards (INV-SM-4)
- [ ] ReentrancyGuard on all state-changing functions
- [ ] CEI pattern followed everywhere
- [ ] No delegatecall to user-controlled addresses
- [ ] No selfdestruct in implementation
- [ ] Storage layout validated for proxy

### Oracle Security
- [ ] Multi-oracle architecture deployed
- [ ] Cross-validation threshold configured
- [ ] Staleness threshold configured
- [ ] L2 sequencer feed checked (if applicable)
- [ ] Circuit breaker tested
- [ ] Fallback oracle tested

### Access Control
- [ ] Admin is multisig (not EOA)
- [ ] Timelock on all parameter changes
- [ ] Roles properly separated
- [ ] No owner() functions that bypass timelock
- [ ] Upgrade mechanism secured

### Economic Security
- [ ] Epoch caps configured
- [ ] Global cap configured
- [ ] LTV ratios conservative
- [ ] Liquidation mechanisms tested
- [ ] Flash loan resistance verified

### Operational Security
- [ ] Monitoring deployed and tested
- [ ] Alerting configured and validated
- [ ] Incident response playbook reviewed
- [ ] Emergency contacts verified
- [ ] Backup procedures tested
