---
name: secure-mint-contracts
description: Smart Contract Generation for SecureMintEngine. Generates production-ready Solidity contracts including BackedToken (ERC-20 dumb ledger), SecureMintPolicy (oracle-gated mint with 6 conditions), Oracle/PoR integration, Emergency Pause, Access Control, Formal Invariants, Simulation requirements, and full test suites. References contract templates in assets/contracts/.
version: 1.0.0
author: Ricardo Prieto
source: ~/.claude/commands/secure-mint-contracts.md
changelog:
  - 1.0.0: Initial version. 8-step contract generation, 6-condition mint gate, threat modeling.
---

# SecureMintEngine -- Smart Contract Generation

## Purpose

Generate a complete, auditable, production-ready smart contract system that enforces the Follow-the-Money Doctrine: tokens may ONLY be minted if backing is provably sufficient via on-chain oracles or Proof-of-Reserve feeds.

**If ANY condition for minting fails, the mint() function MUST revert. No exceptions.**

## Execution Trigger

```bash
make contracts
```

---

## Architecture Overview

```
+-----------------------------------------+
|  ERC-20 Token (DUMB LEDGER)             |
|  - No business logic                    |
|  - Mint callable ONLY by Policy address |
+-----------------------------------------+
             ^
             |
+-----------------------------------------+
|  SecureMint Policy Contract              |
|  - 6 mandatory conditions               |
|  - Oracle health validation             |
|  - Rate limiting and caps               |
+-----------------------------------------+
             ^
             |
+-----------------------------------------+
|  Proof-of-Reserve / Oracle Feeds         |
|  - Chainlink PoR or price feeds         |
|  - Staleness and deviation checks       |
|  - Fallback oracle support              |
+-----------------------------------------+
             ^
             |
+-----------------------------------------+
|  Emergency Pause + Governance Controls   |
|  - 4-level pause system                 |
|  - Guardian multisig                    |
|  - DAO governance with timelocks        |
+-----------------------------------------+
```

---

## Step 1: Token Contract (Dumb Ledger)

Design from `~/.claude/secure-mint-engine/assets/contracts/BackedToken.sol` template.

### Requirements

- Standard ERC-20 implementation (OpenZeppelin base)
- NO embedded business logic
- NO discretionary mint functions
- `mint()` callable ONLY by SecureMint policy contract address
- Optional `burn()` allowed (user-initiated or protocol-initiated)
- Pausable transfers (configurable, controlled by Emergency Pause)
- Role-based access via AccessControl

### Contract Specification

```
BackedToken.sol
  - Inherits: ERC20, ERC20Burnable, ERC20Pausable, AccessControl
  - Roles: DEFAULT_ADMIN_ROLE, MINTER_ROLE, PAUSER_ROLE
  - MINTER_ROLE assigned ONLY to SecureMintPolicy address
  - No EOA may hold MINTER_ROLE
  - Constructor params: name, symbol, policyAddress, adminMultisig
  - Events: TokensMinted(address indexed to, uint256 amount, bytes32 backingProof)
  - Events: TokensBurned(address indexed from, uint256 amount)
```

---

## Step 2: SecureMint Policy Contract

Design from `~/.claude/secure-mint-engine/assets/contracts/SecureMintPolicy.sol` template.

### Six Mandatory Conditions

Minting is allowed IF AND ONLY IF ALL conditions hold simultaneously:

| # | Condition | Implementation | Revert Message |
|---|-----------|---------------|----------------|
| 1 | **Verified backing exists** | Query oracle/PoR feed, verify response is valid | "SM: backing not verified" |
| 2 | **Backing >= post-mint supply** | `backing >= totalSupply + mintAmount` (or required CR) | "SM: insufficient backing" |
| 3 | **Oracle feeds are healthy** | Not stale (`block.timestamp - lastUpdate <= STALENESS_THRESHOLD`), not deviated beyond bounds | "SM: oracle unhealthy" |
| 4 | **Mint amount <= rate limit** | `mintedThisEpoch + amount <= PER_EPOCH_MINT_CAP` | "SM: epoch cap exceeded" |
| 5 | **Mint amount <= global cap** | `totalSupply + amount <= GLOBAL_SUPPLY_CAP` | "SM: global cap exceeded" |
| 6 | **Contract is NOT paused** | `!paused()` | "SM: minting paused" |

**If ANY condition fails, mint() MUST revert.**

### Contract Specification

```
SecureMintPolicy.sol
  - Inherits: AccessControl, Pausable, ReentrancyGuard
  - State variables:
    - IBackedToken public token
    - IBackingOracle public oracle
    - uint256 public GLOBAL_SUPPLY_CAP
    - uint256 public PER_EPOCH_MINT_CAP
    - uint256 public EPOCH_DURATION (default: 1 hour)
    - uint256 public STALENESS_THRESHOLD (default: 3600 seconds)
    - uint256 public DEVIATION_THRESHOLD (default: 500 = 5%)
    - uint256 public MIN_COLLATERAL_RATIO (default: 10000 = 100%)
    - mapping(uint256 => uint256) public mintedPerEpoch
  - Functions:
    - mint(address to, uint256 amount) external onlyRole(MINTER_ROLE)
    - _checkBacking(uint256 amount) internal view returns (bool)
    - _checkOracleHealth() internal view returns (bool)
    - _checkRateLimit(uint256 amount) internal view returns (bool)
    - _currentEpoch() internal view returns (uint256)
    - updateGlobalCap(uint256 newCap) external onlyRole(ADMIN_ROLE) timelocked
    - updateEpochCap(uint256 newCap) external onlyRole(ADMIN_ROLE) timelocked
    - updateOracle(address newOracle) external onlyRole(ADMIN_ROLE) timelocked
  - Events:
    - SecureMint(address indexed to, uint256 amount, uint256 backing, uint256 postMintSupply)
    - MintRejected(address indexed caller, uint256 amount, string reason)
    - OracleUpdated(address indexed oldOracle, address indexed newOracle)
    - CapUpdated(string capType, uint256 oldValue, uint256 newValue)
```

---

## Step 3: Oracle/PoR Configuration

Reference: `~/.claude/secure-mint-engine/references/oracle-requirements.md`

### Mode A: On-Chain Collateral

For crypto-collateralized tokens (CDP model):

- Price oracles for collateral valuation (Chainlink price feeds)
- LTV / collateral ratio enforcement
- Staleness checks: `block.timestamp - oracle.latestTimestamp() <= STALENESS_THRESHOLD`
- Deviation bounds: `|currentPrice - lastPrice| / lastPrice <= DEVIATION_THRESHOLD`
- Emergency pause on oracle failure (auto-trigger)
- Liquidation price monitoring

### Mode B: Off-Chain/Cross-Chain Reserves (Preferred for Stablecoins)

For fiat-backed or RWA-backed tokens:

- Proof-of-Reserve oracle feed (Chainlink PoR)
- Mint blocked if: `reported_reserves < required_backing(post_mint_supply)`
- Continuous enforcement (not one-time attestation)
- Reserve update freshness validation
- Fallback to manual attestation with guardian approval (emergency only)

### Oracle Interface

```
IBackingOracle.sol
  - getBackingAmount() external view returns (uint256)
  - getLastUpdateTimestamp() external view returns (uint256)
  - isHealthy() external view returns (bool)
  - getDeviationBps() external view returns (uint256)
```

---

## Step 4: Emergency Pause

**PAUSE IS NOT OPTIONAL. If pause does not exist, the design is INVALID.**

### Pause Levels

| Level | Scope | Trigger | Authority |
|-------|-------|---------|-----------|
| L0 | Normal operations | N/A | N/A |
| L1 | Pause minting only | Oracle unhealthy, rate anomaly | Guardian multisig OR auto-trigger |
| L2 | Pause minting + transfers | Reserve mismatch, security incident | Guardian multisig |
| L3 | Full freeze (mint + transfer + burn) | Critical exploit, governance vote | DAO emergency vote |

### Mandatory Behaviors

- Instantly block `mint()` at L1+
- Optionally block transfers at L2+ (configurable)
- Callable by Guardian multisig or DAO emergency vote
- Auto-trigger on: oracle unhealthy, reserve mismatch, invariant breach
- Recovery requires explicit unpause with timelock (except L1 auto-recovery)

### Auto-Trigger Conditions

```
IF oracle.isHealthy() == false FOR > 15 minutes:
    -> Auto-pause to L1

IF getBackingAmount() < totalSupply() * MIN_CR:
    -> Auto-pause to L2

IF invariant_breach_detected:
    -> Auto-pause to L3 (requires DAO vote to unpause)
```

---

## Step 5: Access Control and Timelocks

### Mandatory Controls

| Parameter | Requirement | Timelock |
|-----------|-------------|----------|
| GLOBAL_SUPPLY_CAP | Required, immutable or timelocked | 72 hours |
| PER_EPOCH_MINT_CAP | Required | 48 hours |
| RATE_LIMITS | Required | 48 hours |
| ACCESS_CONTROL | No EOAs; multisig only | N/A |
| ORACLE_ADDRESS | Changeable with timelock | 72 hours |
| PAUSE_AUTHORITY | Guardian multisig | N/A |
| ROLE_CHANGES | All role grants/revokes timelocked | 48 hours |
| EMERGENCY_UNPAUSE | Requires DAO vote | 24 hours |

**NO "TEMPORARY UNLIMITED MINT" IS EVER ALLOWED.**

### Timelock Configuration

| Action Type | Delay | Authority |
|-------------|-------|-----------|
| Standard parameter change | 48 hours | Admin multisig |
| Critical parameter change | 72 hours | Admin multisig + DAO approval |
| Emergency action | 24 hours | Guardian multisig |
| Role assignment | 48 hours | Admin multisig |

---

## Step 6: Formal Invariants

Register with MonetaryFormalVerificationEngine. Reference: `~/.claude/secure-mint-engine/references/invariants.md`

### INV-SM-1: BackingAlwaysCoversSupply

```
INVARIANT: backing(t) >= required_backing(totalSupply(t))
FOR ALL t: backing at time t must cover the total supply at time t
VIOLATION: Unbacked tokens exist -> CRITICAL
ACTION: Auto-pause to L2, alert governance
```

### INV-SM-2: OracleHealthRequired

```
INVARIANT: mint() succeeds ONLY IF oracle_healthy == true
FOR ALL mint calls: oracle must report healthy state
VIOLATION: Mint occurred with unhealthy oracle -> CRITICAL
ACTION: Auto-pause to L1, investigate oracle
```

### INV-SM-3: MintIsBounded

```
INVARIANT: minted(epoch) <= epoch_cap AND totalSupply <= global_cap
FOR ALL epochs: cumulative mints within epoch do not exceed cap
VIOLATION: Cap exceeded -> CRITICAL
ACTION: Auto-pause to L2, review rate limits
```

### INV-SM-4: NoBypassPath

```
INVARIANT: No contract, role, or path can mint except SecureMint policy contract
FOR ALL addresses: only the designated policy contract holds MINTER_ROLE
VIOLATION: Unauthorized mint path exists -> CRITICAL
ACTION: Immediately pause all operations, security review
```

---

## Step 7: Simulation and Threat Modeling

Reference: `~/.claude/secure-mint-engine/references/threat-matrix.md`

> **Python Engine:** Use local CLI for bulk validation instead of loading data through context:
> ```bash
> make -C ~/.claude/secure-mint-engine/assets/python-engine invariants    # Check all 4 invariants
> make -C ~/.claude/secure-mint-engine/assets/python-engine simulate BUNDLE=<path>  # Simulate TX bundles
> make -C ~/.claude/secure-mint-engine/assets/python-engine validate-contracts       # Validate .sol files
> ```

### Required Simulations

| Simulation | Parameters | Pass Criteria |
|------------|-----------|---------------|
| Oracle manipulation | +/-30% price deviation | Mint blocked, pause triggered |
| Oracle downtime | 2+ hours stale feed | Mint blocked at STALENESS_THRESHOLD |
| Reserve shortfall | Backing drops below supply | Mint blocked, L2 pause triggered |
| Delayed PoR updates | 24+ hours stale PoR | Mint blocked, alert sent |
| Emergency pause race | Concurrent mint and pause | Pause wins (reentrancy guard) |
| Rate limit boundary | Exact epoch cap amount | Allowed; cap+1 reverts |
| Global cap boundary | Exact global cap amount | Allowed; cap+1 reverts |

### Required Threat Analysis

| Threat | Severity | Mitigation |
|--------|----------|------------|
| Unbacked mint attempt | CRITICAL | 6-condition gate, auto-revert |
| Oracle compromise | CRITICAL | Multi-oracle, deviation bounds, circuit breaker |
| Admin key compromise | HIGH | Multisig, timelocks, no EOA authority |
| Governance capture | HIGH | Timelock, guardian veto, quorum requirements |
| False reserve reporting | CRITICAL | Multiple attestation sources, continuous monitoring |
| Flash loan attack | HIGH | TWAP oracle, single-block manipulation prevention |
| Reentrancy on mint | HIGH | ReentrancyGuard, CEI pattern |

**Any unmitigated fatal scenario results in NO-GO for deployment.**

---

## Step 8: Integration Requirements

SecureMintEngine MUST integrate with all of these engines:

| Engine | Integration Point | Data Flow |
|--------|------------------|-----------|
| TokenMonetaryEngine | Supply tracking | Mint/burn events |
| MonetaryFormalVerificationEngine | Invariant registration | INV-SM-1 through INV-SM-4 |
| TreasuryEngine | Reserve custody | Backing amount queries |
| EvidenceLoggingEngine | Immutable audit trail | All mint/burn events with oracle state |
| KillSwitchWorkflow | Emergency controls | Pause triggers and recovery |
| DAO / Multi-Sig Gate | Governance approvals | Parameter changes, unpause |
| Enforcement and Litigation Readiness | Legal evidence | Timestamped operation logs |

All mint/burn events MUST be:
- Immutably logged (on-chain events)
- Timestamped (block.timestamp)
- Linked to oracle state at time of execution (backing amount, oracle health)

---

## Contract File Listing

```
contracts/
  BackedToken.sol                # ERC-20 dumb ledger with restricted mint
  SecureMintPolicy.sol           # Oracle-gated mint policy (6 conditions)
  EmergencyPause.sol             # 4-level circuit breaker
  TreasuryVault.sol              # Multi-tier reserve custody
  ChainlinkPoRAdapter.sol        # Chainlink PoR integration adapter
  OracleRouter.sol               # Multi-oracle routing with fallback
  Governor.sol                   # DAO governance contract
  Timelock.sol                   # Execution delay for parameter changes
  RedemptionEngine.sol           # Burn-to-redeem mechanism
  GuardianMultisig.sol           # Guardian authority management
  IBackingOracle.sol             # Oracle interface specification
  IBackedToken.sol               # Token interface
  ISecureMintPolicy.sol          # Policy interface
  ITreasuryVault.sol             # Treasury interface
  IEmergencyPause.sol            # Pause interface
```

---

## Test Suite Specifications

### Unit Tests

```
test/unit/
  BackedToken.t.sol
    - should deploy with correct name and symbol
    - should assign MINTER_ROLE only to policy address
    - should allow mint only from MINTER_ROLE
    - should revert mint from non-MINTER address
    - should allow burn by token holder
    - should pause/unpause transfers
    - should not allow EOA to hold MINTER_ROLE

  SecureMintPolicy.t.sol
    - should mint when all 6 conditions pass
    - should revert when backing is insufficient (condition 1)
    - should revert when post-mint supply exceeds backing (condition 2)
    - should revert when oracle is stale (condition 3)
    - should revert when oracle deviation exceeds threshold (condition 3)
    - should revert when epoch cap is exceeded (condition 4)
    - should revert when global cap is exceeded (condition 5)
    - should revert when contract is paused (condition 6)
    - should track minted amount per epoch correctly
    - should reset epoch counter after epoch duration
    - should emit SecureMint event on successful mint
    - should emit MintRejected event on failed mint

  ChainlinkPoRAdapter.t.sol
    - should return backing amount from Chainlink PoR
    - should report unhealthy when feed is stale
    - should report unhealthy when deviation exceeds threshold
    - should handle oracle returning zero

  OracleRouter.t.sol
    - should route to primary oracle
    - should support fallback oracle
    - should failover when primary is unhealthy

  EmergencyPause.t.sol
    - should pause at L1 (mint only)
    - should pause at L2 (mint + transfers)
    - should pause at L3 (full freeze)
    - should auto-trigger on oracle failure
    - should require timelock for unpause

  TreasuryVault.t.sol
    - should accept deposits
    - should track reserve balances
    - should enforce withdrawal restrictions

  Governor.t.sol
    - should create governance proposals
    - should enforce quorum requirements
    - should execute passed proposals via timelock

  Timelock.t.sol
    - should enforce minimum delay
    - should queue and execute operations
    - should allow cancel by admin

  RedemptionEngine.t.sol
    - should burn tokens and release collateral
    - should calculate correct redemption amount minus fees
    - should handle partial redemption
    - should block redemption when L3 paused

  GuardianMultisig.t.sol
    - should require threshold signatures
    - should execute emergency pause
    - should not allow single signer actions
```

### Integration Tests

```
test/integration/
  MintFlow.t.sol
    - should complete full mint flow: oracle check -> backing check -> rate limit -> mint
    - should handle concurrent mint requests within epoch cap
    - should reject mint when oracle goes stale mid-epoch
    - should auto-pause when backing drops below supply
    - should resume minting after pause is lifted

  RedemptionFlow.t.sol
    - should burn tokens and release collateral
    - should calculate correct redemption amount minus fees
    - should handle partial redemption
    - should block redemption when L3 paused
```

### Invariant Tests (Foundry)

```
test/invariant/
  Invariants.t.sol
    - invariant_backingCoversSupply: backing >= totalSupply at all times
    - invariant_oracleHealthForMint: no mint occurred with unhealthy oracle
    - invariant_mintBounded: minted per epoch <= epoch cap, totalSupply <= global cap
    - invariant_noBypassPath: only policy contract holds MINTER_ROLE
    - invariant_pauseBlocksMint: no mint occurred while paused
```

---

## References

- `~/.claude/secure-mint-engine/assets/contracts/` -- Solidity reference implementations (BackedToken.sol, SecureMintPolicy.sol, IBackingOracle.sol)
- `~/.claude/secure-mint-engine/references/oracle-requirements.md` -- Detailed oracle/PoR specifications
- `~/.claude/secure-mint-engine/references/invariants.md` -- Formal invariants for verification
- `~/.claude/secure-mint-engine/references/threat-matrix.md` -- Threat modeling requirements

---

## Absolute Rules

1. **Mint reverts if ANY of the 6 conditions fails.** No partial checks, no soft failures.
2. **No EOA may hold MINTER_ROLE.** Only the SecureMintPolicy contract address.
3. **Pause is mandatory.** A design without emergency pause is INVALID.
4. **All invariants must be testable.** Each INV-SM must have a corresponding test.
5. **No temporary unlimited mint.** Rate limits and caps are always enforced.
6. **All parameter changes require timelocks.** No instant parameter modifications.
7. **Any unmitigated fatal threat is a NO-GO.** Deployment is blocked until resolved.
