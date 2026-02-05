# Formal Invariants for SecureMintEngine Verification

> This document defines the formal invariants that MUST hold true at all times across
> every SecureMintEngine deployment. These invariants form the mathematical foundation
> of the system's security guarantees and are enforceable via Foundry invariant tests.

---

## Table of Contents

1. [Invariant Overview](#invariant-overview)
2. [INV-SM-1: BackingAlwaysCoversSupply](#inv-sm-1-backingalwayscoversupply)
3. [INV-SM-2: OracleHealthRequired](#inv-sm-2-oraclehealthrequired)
4. [INV-SM-3: MintIsBounded](#inv-sm-3-mintisbounded)
5. [INV-SM-4: NoBypassPath](#inv-sm-4-nobypasspath)
6. [INV-SM-5: BurnReducesSupply](#inv-sm-5-burnreducessupply)
7. [INV-SM-6: PauseHaltsAllMinting](#inv-sm-6-pausehaltsallminting)
8. [INV-SM-7: ReserveRatioMonotonic](#inv-sm-7-reserveratiomonotonic)
9. [Foundry Invariant Test Patterns](#foundry-invariant-test-patterns)
10. [Violation Detection & Response](#violation-detection--response)

---

## Invariant Overview

| ID | Name | Severity | Formula |
|----|------|----------|---------|
| INV-SM-1 | BackingAlwaysCoversSupply | CRITICAL | `reserves >= totalSupply * reserveRatio` |
| INV-SM-2 | OracleHealthRequired | CRITICAL | `oracleAge <= maxStaleness AND oraclePrice > 0` |
| INV-SM-3 | MintIsBounded | HIGH | `epochMinted <= epochCap AND globalMinted <= globalCap` |
| INV-SM-4 | NoBypassPath | CRITICAL | `mint() requires ALL guards pass` |
| INV-SM-5 | BurnReducesSupply | HIGH | `postBurnSupply == preBurnSupply - burnAmount` |
| INV-SM-6 | PauseHaltsAllMinting | CRITICAL | `paused == true => mint() always reverts` |
| INV-SM-7 | ReserveRatioMonotonic | MEDIUM | `reserveRatio never decreases except via governance` |

---

## INV-SM-1: BackingAlwaysCoversSupply

### Statement

At any point in time, the total value of reserves (on-chain collateral or attested off-chain reserves) MUST be greater than or equal to the total supply of minted tokens multiplied by the required reserve ratio.

### Formal Definition

```
INVARIANT INV-SM-1:
  FOR ALL states s IN system_states:
    reserves(s) >= totalSupply(s) * reserveRatio(s)

WHERE:
  reserves(s) =
    IF mode == MODE_A (on-chain collateral):
      SUM(collateral_i * oraclePrice_i) FOR ALL collateral deposits i
    ELIF mode == MODE_B (off-chain/cross-chain PoR):
      latestPoRFeedValue

  totalSupply(s) = token.totalSupply()
  reserveRatio(s) = configuredReserveRatio  // Default: 1.0 (100%)
```

### Boundary Conditions

- Holds true during mint operations: `reserves(s') >= (totalSupply(s) + mintAmount) * reserveRatio`
- Holds true during price changes: If `oraclePrice` drops, minting pauses before invariant breaks
- Holds true during redemptions: Burns reduce `totalSupply`, maintaining or improving ratio
- Edge case: When `totalSupply == 0`, invariant is trivially satisfied

### Solidity Assertion

```solidity
function invariant_BackingAlwaysCoversSupply() public view {
    uint256 reserves = _getReserves();
    uint256 supply = token.totalSupply();
    uint256 ratio = reserveRatio; // 1e18 = 100%
    assert(reserves >= (supply * ratio) / 1e18);
}
```

### Violation Impact

**Catastrophic** -- Users hold tokens that are not fully backed. This is the fundamental promise of the system.

---

## INV-SM-2: OracleHealthRequired

### Statement

No minting operation may execute unless the oracle price feed is healthy: fresh, positive, and complete.

### Formal Definition

```
INVARIANT INV-SM-2:
  FOR ALL mint operations m:
    PRE(m) =>
      oracleTimestamp(m) > 0
      AND (block.timestamp - oracleTimestamp(m)) <= maxStaleness
      AND oraclePrice(m) > 0
      AND oracleRound(m).answeredInRound >= oracleRound(m).roundId

  IF chain.isL2:
    PRE(m) =>
      sequencerStatus == UP
      AND (block.timestamp - sequencerUpSince) > gracePeriod
```

### Health Check Components

| Check | Condition | Failure Mode |
|-------|-----------|-------------|
| **Freshness** | `block.timestamp - updatedAt <= maxStaleness` | Oracle stopped updating |
| **Positivity** | `answer > 0` | Oracle returning garbage |
| **Completeness** | `answeredInRound >= roundId` | Round not finalized |
| **Timestamp Valid** | `updatedAt > 0` | Round never started |
| **Sequencer Up** (L2) | `sequencerAnswer == 0` | L2 sequencer down |
| **Grace Period** (L2) | `timeSinceUp > gracePeriod` | Sequencer just restarted |

### Solidity Assertion

```solidity
function invariant_OracleHealthRequired() public {
    // Attempt mint with unhealthy oracle should always revert
    vm.mockCall(
        address(oracle),
        abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
        abi.encode(uint80(1), int256(0), uint256(0), uint256(0), uint80(0))
    );
    vm.expectRevert("SME: invalid price");
    policy.mint(address(this), 1e18);
}
```

### Violation Impact

**Critical** -- Minting against manipulated or stale prices leads to undercollateralized tokens.

---

## INV-SM-3: MintIsBounded

### Statement

Minting is rate-limited at both the epoch level and global level. No single epoch may mint more than `epochCap`, and the cumulative total minted may never exceed `globalCap`.

### Formal Definition

```
INVARIANT INV-SM-3:
  FOR ALL epochs e:
    mintedInEpoch(e) <= epochCap

  AND:
    totalEverMinted <= globalCap

WHERE:
  epoch = floor(block.timestamp / epochDuration)
  epochDuration = configurable (default: 24 hours = 86400 seconds)
  epochCap = configurable per governance
  globalCap = configurable per governance
```

### Cap Configuration Defaults

| Parameter | Default | Range | Governance Timelock |
|-----------|---------|-------|-------------------|
| `epochDuration` | 86400 (24h) | 3600 - 604800 | 48h timelock |
| `epochCap` | 1% of totalSupply | 0.1% - 5% | 48h timelock |
| `globalCap` | 100M tokens | Project-specific | 48h timelock |
| `perTxCap` | 0.1% of totalSupply | 0.01% - 1% | 24h timelock |

### Solidity Assertion

```solidity
function invariant_MintIsBounded() public view {
    uint256 currentEpoch = block.timestamp / epochDuration;
    uint256 epochMinted = mintedPerEpoch[currentEpoch];
    uint256 globalMinted = totalMinted;
    assert(epochMinted <= epochCap);
    assert(globalMinted <= globalCap);
}
```

### Violation Impact

**High** -- Unbounded minting can dilute token value and overwhelm reserves.

---

## INV-SM-4: NoBypassPath

### Statement

There exists NO code path through which tokens can be minted without ALL of the following guards passing:

1. Oracle health check (INV-SM-2)
2. Reserve sufficiency check (INV-SM-1)
3. Rate limit check (INV-SM-3)
4. Access control check (authorized minter)
5. Pause state check (not paused)

### Formal Definition

```
INVARIANT INV-SM-4:
  FOR ALL functions f IN contract:
    IF f modifies totalSupply upward:
      f MUST include:
        GUARD_1: oracleHealthy()     // INV-SM-2
        GUARD_2: reserveSufficient() // INV-SM-1
        GUARD_3: withinEpochCap()    // INV-SM-3
        GUARD_4: onlyMinter()        // Access control
        GUARD_5: whenNotPaused()     // Circuit breaker

  AND:
    NO function f exists where:
      totalSupply increases AND any GUARD_i is skipped

  AND:
    Contract is NOT upgradeable
    OR upgrade requires timelock + multisig
```

### Access Control Proof

```solidity
// The ONLY function that increases totalSupply:
function mint(
    address to,
    uint256 amount
) external
    onlyRole(MINTER_ROLE)     // GUARD_4: Access control
    whenNotPaused()            // GUARD_5: Circuit breaker
    oracleHealthy()            // GUARD_1: Oracle health
    reserveSufficient(amount)  // GUARD_2: Reserve check
    withinEpochCap(amount)     // GUARD_3: Rate limit
{
    _mint(to, amount);
    totalMinted += amount;
    mintedPerEpoch[_currentEpoch()] += amount;
    emit TokensMinted(to, amount, _currentEpoch());
}
```

### Verification Approach

1. **Static Analysis**: Slither/Mythril to find all `_mint` call sites
2. **Manual Review**: Ensure every `_mint` is behind ALL 5 guards
3. **Invariant Test**: Fuzz all entry points to confirm no bypass
4. **Formal Verification**: Certora/Halmos for mathematical proof

### Solidity Invariant Test

```solidity
function invariant_NoBypassPath() public {
    uint256 newSupply = token.totalSupply();
    uint256 oldSupply = ghost_previousSupply;

    if (newSupply > oldSupply) {
        assert(ghost_lastMintOracleHealthy == true);
        assert(ghost_lastMintReservesSufficient == true);
        assert(ghost_lastMintWithinCap == true);
        assert(ghost_lastMintCallerAuthorized == true);
        assert(ghost_lastMintNotPaused == true);
    }
    ghost_previousSupply = newSupply;
}
```

### Violation Impact

**Catastrophic** -- Any bypass path allows unauthorized/unbacked minting.

---

## INV-SM-5: BurnReducesSupply

### Statement

Every burn operation MUST reduce totalSupply by exactly the burned amount, and no burn may reduce supply below zero.

### Formal Definition

```
INVARIANT INV-SM-5:
  FOR ALL burn operations b:
    totalSupply(post_b) == totalSupply(pre_b) - burnAmount(b)
  AND:
    burnAmount(b) <= balanceOf(burner)
    burnAmount(b) > 0
```

### Solidity Assertion

```solidity
function invariant_BurnReducesSupply() public {
    uint256 supplyBefore = token.totalSupply();
    uint256 burnAmount = bound(randomAmount, 1, supplyBefore);
    address burner = ghost_randomHolder;
    vm.assume(token.balanceOf(burner) >= burnAmount);
    vm.prank(burner);
    token.burn(burnAmount);
    assert(token.totalSupply() == supplyBefore - burnAmount);
}
```

---

## INV-SM-6: PauseHaltsAllMinting

### Statement

When the system is paused, ALL minting operations MUST revert regardless of any other conditions being satisfied.

### Formal Definition

```
INVARIANT INV-SM-6:
  FOR ALL states s WHERE paused(s) == true:
    FOR ALL mint attempts m:
      m REVERTS

  AND:
    pause() can be called by: PAUSER_ROLE OR GUARDIAN_ROLE
    unpause() can be called by: ADMIN_ROLE (with timelock)
```

### Pause Authority

| Action | Required Role | Timelock |
|--------|-------------|----------|
| `pause()` | PAUSER_ROLE OR GUARDIAN_ROLE | None (immediate) |
| `unpause()` | ADMIN_ROLE | 24h minimum |
| `emergencyPause()` | Any EOA via guardian multisig | None (immediate) |

### Solidity Assertion

```solidity
function invariant_PauseHaltsAllMinting() public {
    if (policy.paused()) {
        vm.expectRevert("Pausable: paused");
        policy.mint(address(this), 1);

        vm.expectRevert("Pausable: paused");
        policy.batchMint(recipients, amounts);

        assert(token.totalSupply() == ghost_supplyAtPause);
    }
}
```

---

## INV-SM-7: ReserveRatioMonotonic

### Statement

The reserve ratio configuration may only decrease through an explicit governance action with timelock. No market action, oracle update, or operational event may lower the configured ratio.

### Formal Definition

```
INVARIANT INV-SM-7:
  FOR ALL state transitions s -> s':
    IF reserveRatio(s') < reserveRatio(s):
      transition MUST be governance_action WITH timelock >= 48 hours

  NOTE: The ACTUAL reserve level (reserves / totalSupply) may fluctuate
  due to market conditions. This invariant concerns the CONFIGURED ratio.
```

---

## Foundry Invariant Test Patterns

### Test Harness Setup

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/InvariantTest.sol";

contract SecureMintInvariantTest is Test {
    SecureMintPolicy public policy;
    MockToken public token;
    MockOracle public oracle;
    MintHandler public handler;

    function setUp() public {
        token = new MockToken();
        oracle = new MockOracle();
        policy = new SecureMintPolicy(address(token), address(oracle));

        token.grantRole(token.MINTER_ROLE(), address(policy));

        handler = new MintHandler(policy, token, oracle);
        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = handler.mint.selector;
        selectors[1] = handler.burn.selector;
        selectors[2] = handler.updateOracle.selector;
        selectors[3] = handler.togglePause.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_BackingAlwaysCoversSupply() public view {
        uint256 reserves = policy.getReserves();
        uint256 supply = token.totalSupply();
        uint256 ratio = policy.reserveRatio();
        assert(reserves >= (supply * ratio) / 1e18);
    }

    function invariant_MintIsBounded() public view {
        uint256 currentEpoch = block.timestamp / policy.epochDuration();
        assert(policy.mintedPerEpoch(currentEpoch) <= policy.epochCap());
        assert(policy.totalMinted() <= policy.globalCap());
    }

    function invariant_SupplyMatchesMintMinusBurn() public view {
        assert(
            token.totalSupply() ==
            handler.ghost_totalMinted() - handler.ghost_totalBurned()
        );
    }

    function invariant_PauseBlocksMint() public view {
        if (policy.paused()) {
            assert(handler.ghost_mintsSincePause() == 0);
        }
    }
}
```

### Handler Contract (Guided Fuzzing)

```solidity
contract MintHandler is CommonBase, StdCheats, StdUtils {
    SecureMintPolicy public policy;
    MockToken public token;
    MockOracle public oracle;

    uint256 public ghost_totalMinted;
    uint256 public ghost_totalBurned;
    uint256 public ghost_mintsSincePause;
    bool public ghost_lastMintOracleHealthy;
    bool public ghost_lastMintReservesSufficient;

    constructor(SecureMintPolicy _policy, MockToken _token, MockOracle _oracle) {
        policy = _policy;
        token = _token;
        oracle = _oracle;
    }

    function mint(uint256 amount) external {
        amount = bound(amount, 0, policy.epochCap());
        try policy.mint(msg.sender, amount) {
            ghost_totalMinted += amount;
            ghost_lastMintOracleHealthy = true;
            ghost_lastMintReservesSufficient = true;
            if (policy.paused()) ghost_mintsSincePause++;
        } catch {}
    }

    function burn(uint256 amount) external {
        uint256 balance = token.balanceOf(msg.sender);
        amount = bound(amount, 0, balance);
        if (amount > 0) {
            vm.prank(msg.sender);
            token.burn(amount);
            ghost_totalBurned += amount;
        }
    }

    function updateOracle(int256 price, uint256 staleness) external {
        price = int256(bound(uint256(price), 0, 1e24));
        staleness = bound(staleness, 0, 7200);
        oracle.setPrice(price);
        oracle.setTimestamp(block.timestamp - staleness);
    }

    function togglePause() external {
        if (policy.paused()) {
            policy.unpause();
        } else {
            policy.pause();
            ghost_mintsSincePause = 0;
        }
    }
}
```

### Running Invariant Tests

```bash
# Basic invariant test run
forge test --match-contract InvariantTest -vvv

# With increased depth
forge test --match-contract InvariantTest -vvv --fuzz-runs 1000 --fuzz-depth 100

# With specific seed for reproducibility
forge test --match-contract InvariantTest -vvv --fuzz-seed 42
```

### foundry.toml Configuration

```toml
[invariant]
runs = 256
depth = 128
fail_on_revert = false
call_override = false
dictionary_weight = 80
include_storage = true
include_push_bytes = true
```

---

## Violation Detection & Response

### Automated Detection

| Invariant | Detection Method | Response Time |
|-----------|-----------------|---------------|
| INV-SM-1 | On-chain modifier + off-chain monitor | Immediate / < 1 min |
| INV-SM-2 | Oracle health check in modifier | Immediate |
| INV-SM-3 | Epoch counter in mint function | Immediate |
| INV-SM-4 | Static analysis in CI + runtime check | Per-commit / immediate |
| INV-SM-5 | Post-burn supply assertion | Immediate |
| INV-SM-6 | Pause state check in modifier | Immediate |
| INV-SM-7 | Governance event monitoring | < 5 min |

### Response Procedures

#### Severity: CATASTROPHIC (INV-SM-1, INV-SM-4 violated)

1. **Immediate** (0-5 min): Emergency pause via guardian multisig
2. **Assessment** (5-30 min): Quantify exposure, identify root cause
3. **Communication** (30-60 min): Public incident disclosure
4. **Remediation** (1-24h): Deploy fix, compensate affected users
5. **Post-mortem** (24-72h): Root cause analysis, process improvements

#### Severity: CRITICAL (INV-SM-2, INV-SM-6 violated)

1. **Immediate** (0-5 min): Automatic pause or manual pause
2. **Diagnosis** (5-60 min): Determine if oracle issue or contract bug
3. **Resolution** (1-4h): Switch oracle, adjust parameters, or deploy fix
4. **Monitoring** (4-24h): Enhanced monitoring during recovery

#### Severity: HIGH (INV-SM-3, INV-SM-5 violated)

1. **Alert** (0-5 min): Team notification
2. **Investigation** (5-30 min): Review triggering transactions
3. **Mitigation** (30-120 min): Reduce caps, add restrictions
4. **Fix** (1-48h): Deploy corrective update

#### Severity: MEDIUM (INV-SM-7 violated)

1. **Monitor**: Flag governance proposal that reduces ratio
2. **Review**: Ensure timelock was respected
3. **Communicate**: Inform community of ratio change
4. **Document**: Update risk parameters documentation

### Emergency Contact Chain

```
Level 1: On-call engineer      -> PagerDuty alert
Level 2: Security lead          -> Phone call (5 min)
Level 3: CTO / Protocol lead    -> Phone call (15 min)
Level 4: Legal / Compliance     -> Email + call (30 min)
Level 5: External auditor       -> Email (1 hour)
```
