# Oracle & Proof-of-Reserve Requirements

> Comprehensive specification for oracle integration in the SecureMintEngine ecosystem.
> Oracles are the single most critical dependency — if the oracle lies, the peg dies.

---

## Table of Contents

1. [Mode A: On-Chain Collateral](#mode-a-on-chain-collateral)
2. [Mode B: Off-Chain / Cross-Chain Proof of Reserve](#mode-b-off-chain--cross-chain-proof-of-reserve)
3. [Oracle Selection Criteria](#oracle-selection-criteria)
4. [Heartbeat & Deviation Thresholds](#heartbeat--deviation-thresholds)
5. [Fallback Oracle Patterns](#fallback-oracle-patterns)
6. [Integration Code Snippets](#integration-code-snippets)
7. [Monitoring & Alerting](#monitoring--alerting)

---

## Mode A: On-Chain Collateral

Mode A applies when collateral is **natively on-chain** (e.g., ETH, WBTC, staked assets). The oracle provides real-time price feeds to enforce Loan-to-Value (LTV) ratios.

### Price Oracle Requirements

| Parameter | Requirement | Rationale |
|-----------|------------|-----------|
| **Staleness Threshold** | 1 hour (3600 seconds) | Prevents minting against stale prices that could be manipulated |
| **Deviation Threshold** | +/- 5% from last update | Forces update when price moves significantly |
| **Minimum Sources** | 3 independent data sources | Prevents single-source manipulation |
| **Update Frequency** | Heartbeat OR deviation, whichever triggers first | Ensures freshness under all market conditions |
| **Decimal Precision** | 8 decimals minimum (18 preferred) | Matches Chainlink standard; prevents rounding exploits |

### LTV Enforcement

```
LTV = (Total Debt in USD) / (Total Collateral Value in USD)
```

| Collateral Type | Max LTV | Liquidation LTV | Buffer Zone |
|----------------|---------|-----------------|-------------|
| ETH / WETH | 75% | 82.5% | 7.5% |
| WBTC | 70% | 80% | 10% |
| Staked ETH (stETH, rETH) | 70% | 80% | 10% |
| Stablecoins (USDC, DAI) | 90% | 95% | 5% |
| Volatile ERC-20s | 50% | 65% | 15% |
| LP Tokens | 60% | 75% | 15% |

### Auto-Pause Conditions

The minting contract MUST automatically pause when ANY of the following occur:

1. **Oracle Staleness**: `block.timestamp - lastUpdate > STALENESS_THRESHOLD`
2. **Price Deviation Spike**: Price moves > 15% in a single update
3. **Sequencer Down** (L2 only): Chainlink L2 sequencer uptime feed reports down
4. **Zero Price**: Oracle returns 0 or negative value
5. **Round Incompleteness**: `answeredInRound < roundId` (Chainlink specific)

```solidity
modifier oracleHealthy() {
    (
        uint80 roundId,
        int256 answer,
        ,
        uint256 updatedAt,
        uint80 answeredInRound
    ) = priceFeed.latestRoundData();

    require(answer > 0, "SME: invalid price");
    require(updatedAt > 0, "SME: round not complete");
    require(answeredInRound >= roundId, "SME: stale round");
    require(
        block.timestamp - updatedAt <= STALENESS_THRESHOLD,
        "SME: stale price"
    );
    _;
}
```

### LTV Enforcement Logic

```solidity
function _enforceLTV(address user, uint256 additionalDebt) internal view {
    uint256 collateralValue = _getCollateralValueUSD(user);
    uint256 totalDebt = userDebt[user] + additionalDebt;
    uint256 currentLTV = (totalDebt * 1e18) / collateralValue;
    require(currentLTV <= maxLTV[collateralType], "SME: LTV exceeded");
}
```

---

## Mode B: Off-Chain / Cross-Chain Proof of Reserve

Mode B applies when reserves are held **off-chain** (bank accounts, custodians) or on **another blockchain**. Chainlink Proof of Reserve (PoR) feeds provide cryptographic attestation.

### Chainlink PoR Feed Requirements

| Parameter | Requirement | Rationale |
|-----------|------------|-----------|
| **Feed Type** | Chainlink Proof of Reserve | Industry standard for reserve attestation |
| **Update Cadence** | At least every 24 hours | Daily attestation minimum |
| **Enforcement** | Continuous -- checked on every mint | No minting window without valid proof |
| **Reserve Ratio** | >= 100% at all times | Full backing is non-negotiable |
| **Overcollateralization** | Recommended >= 105% | Buffer for market movements |

### Reserve Reporting

```solidity
interface IPoRFeed {
    function latestRoundData() external view returns (
        uint80 roundId, int256 reserves, uint256 startedAt,
        uint256 updatedAt, uint80 answeredInRound
    );
}

function _checkReserves(uint256 additionalMint) internal view {
    (, int256 reserves, , uint256 updatedAt, ) = porFeed.latestRoundData();
    require(reserves > 0, "SME: invalid reserves");
    require(block.timestamp - updatedAt <= POR_STALENESS, "SME: stale PoR");
    uint256 totalSupplyAfterMint = token.totalSupply() + additionalMint;
    require(uint256(reserves) >= totalSupplyAfterMint, "SME: insufficient reserves");
}
```

### Cross-Chain Reserve Verification

For reserves on another chain (e.g., Bitcoin reserves for a WBTC-like token):

1. **Chainlink PoR** reads Bitcoin addresses directly
2. Feed aggregates total BTC balance across all custodian addresses
3. On-chain contract compares reported BTC reserves against total token supply
4. Minting blocked if `reserves < totalSupply * RESERVE_RATIO`

### Attestation Provider Requirements

| Provider | Acceptable | Notes |
|----------|-----------|-------|
| Chainlink PoR | YES | Gold standard |
| Armanino TrustExplorer | YES (supplementary) | Real-time attestation dashboard |
| Big Four Audit | YES (supplementary) | Quarterly, not real-time |
| Self-Attestation | NO | Never acceptable as sole proof |

---

## Oracle Selection Criteria

### Provider Comparison Matrix

| Criteria | Chainlink | Pyth | Redstone | API3 |
|----------|-----------|------|----------|------|
| **EVM Support** | Full | Full | Full | Full |
| **Solana Support** | Limited | Native | No | No |
| **Decentralization** | High (DON) | Medium (publishers) | Medium | Medium (first-party) |
| **Price Feed Count** | 1000+ | 400+ | 200+ | 150+ |
| **Update Model** | Push (heartbeat+deviation) | Pull (on-demand) | Pull (on-demand) | Push (Airnode) |
| **Latency** | ~1 block | Sub-second | ~1 block | ~1 block |
| **Cost** | Free to consume | Gas on pull | Gas on pull | Sponsor pays |
| **PoR Support** | YES | NO | NO | NO |
| **L2 Sequencer Feed** | YES | NO | NO | NO |
| **Battle-Tested TVL** | $20B+ secured | $2B+ secured | $500M+ secured | $200M+ secured |

### Selection Decision Tree

```
IF reserve_type == "off_chain" OR reserve_type == "cross_chain":
    REQUIRE Chainlink PoR (no alternative)

IF chain == "Solana":
    PRIMARY = Pyth
    FALLBACK = Switchboard

IF chain == "EVM":
    IF asset is major (ETH, BTC, USDC):
        PRIMARY = Chainlink
        SECONDARY = Pyth OR Redstone
    ELIF asset is long-tail:
        PRIMARY = Redstone OR API3
        SECONDARY = Chainlink (if available)
        REQUIRE: TWAP oracle as additional check
```

### Minimum Viable Oracle Setup

Every SecureMintEngine deployment MUST have:

1. **Primary Oracle**: Production-grade feed with >= 3 data sources
2. **Secondary Oracle**: Independent provider for cross-validation
3. **Circuit Breaker**: Deviation > X% between primary and secondary triggers pause
4. **Staleness Guard**: Time-based expiry on all feeds
5. **Zero/Negative Guard**: Reject non-positive values

---

## Heartbeat & Deviation Thresholds

### Per-Asset-Type Configuration

| Asset Category | Heartbeat | Deviation | Staleness | Rationale |
|---------------|-----------|-----------|-----------|-----------|
| **Major Stablecoins** (USDC, USDT, DAI) | 24h | 0.25% | 86400s | Low volatility; depeg detection |
| **ETH / BTC** | 1h | 1% | 3600s | High liquidity but volatile |
| **Large Cap ERC-20** (UNI, AAVE, LINK) | 1h | 2% | 3600s | Moderate volatility |
| **Mid Cap ERC-20** | 30min | 3% | 1800s | Higher volatility |
| **Small Cap / Long Tail** | 20min | 5% | 1200s | High volatility, low liquidity |
| **LP Tokens** | 1h | 3% | 3600s | Derived pricing, manipulation risk |
| **Staked Derivatives** (stETH, rETH) | 1h | 2% | 3600s | Exchange rate + underlying |
| **RWA Tokens** | 24h | 1% | 86400s | Slow-moving |
| **Commodities** (Gold, Silver) | 1h | 1% | 3600s | Market hours dependent |

### L2-Specific Adjustments

| L2 Network | Additional Requirement |
|-----------|----------------------|
| Arbitrum | Check Sequencer Uptime Feed; add GRACE_PERIOD (3600s) after restart |
| Optimism | Check Sequencer Uptime Feed; add GRACE_PERIOD (3600s) after restart |
| Base | Check Sequencer Uptime Feed; add GRACE_PERIOD (3600s) after restart |
| Polygon PoS | No sequencer feed needed; use standard staleness |
| zkSync Era | Monitor prover delays; extend staleness by 2x during proof generation |

---

## Fallback Oracle Patterns

### Three-Tier Fallback Architecture

```
Tier 1 (Primary)   -> Chainlink Price Feed
    | (if stale/invalid)
Tier 2 (Secondary)  -> Pyth Network / Redstone
    | (if stale/invalid)
Tier 3 (Emergency)  -> TWAP from on-chain DEX (Uniswap V3)
    | (if all fail)
CIRCUIT BREAKER     -> Pause all minting
```

### Implementation Pattern

```solidity
contract OracleRouter {
    IOracleAdapter public primaryOracle;
    IOracleAdapter public secondaryOracle;
    IOracleAdapter public emergencyOracle;

    uint256 public constant MAX_DEVIATION_BPS = 500; // 5%

    function getPrice(address asset) external view returns (uint256 price, uint8 confidence) {
        (bool ok1, uint256 p1) = _tryGetPrice(primaryOracle, asset, 3600);
        if (ok1) {
            (bool ok2, uint256 p2) = _tryGetPrice(secondaryOracle, asset, 7200);
            if (ok2) {
                uint256 deviation = _calculateDeviation(p1, p2);
                require(deviation <= MAX_DEVIATION_BPS, "SME: oracle deviation too high");
            }
            return (p1, 3);
        }
        (bool ok2, uint256 p2) = _tryGetPrice(secondaryOracle, asset, 7200);
        if (ok2) return (p2, 2);
        (bool ok3, uint256 p3) = _tryGetPrice(emergencyOracle, asset, 14400);
        if (ok3) return (p3, 1);
        revert("SME: all oracles failed");
    }

    function _tryGetPrice(IOracleAdapter oracle, address asset, uint256 maxStaleness)
        internal view returns (bool, uint256)
    {
        try oracle.getPrice(asset) returns (uint256 _price, uint256 _updatedAt) {
            if (_price > 0 && block.timestamp - _updatedAt <= maxStaleness)
                return (true, _price);
        } catch {}
        return (false, 0);
    }

    function _calculateDeviation(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 diff = a > b ? a - b : b - a;
        return (diff * 10000) / ((a + b) / 2);
    }
}
```

### Confidence-Based Minting Limits

| Confidence | Oracle Source | Minting Allowed | Max Per-Tx |
|------------|-------------|-----------------|------------|
| 3 (High) | Primary + cross-validated | Full | Epoch limit |
| 2 (Medium) | Secondary only | Reduced (50%) | 50% epoch limit |
| 1 (Low) | Emergency TWAP | Minimal (10%) | 10% epoch limit |
| 0 (None) | All failed | PAUSED | 0 |

---

## Integration Code Snippets

### Chainlink Price Feed

```solidity
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ChainlinkAdapter is IOracleAdapter {
    AggregatorV3Interface public immutable feed;
    uint8 public immutable feedDecimals;

    constructor(address _feed) {
        feed = AggregatorV3Interface(_feed);
        feedDecimals = feed.decimals();
    }

    function getPrice(address) external view override returns (uint256 price, uint256 updatedAt) {
        (uint80 roundId, int256 answer, , uint256 _updatedAt, uint80 answeredInRound) =
            feed.latestRoundData();
        require(answer > 0, "Invalid price");
        require(answeredInRound >= roundId, "Stale round");
        require(_updatedAt > 0, "Round not complete");
        price = uint256(answer) * 10 ** (18 - feedDecimals);
        updatedAt = _updatedAt;
    }
}
```

### Pyth Network

```solidity
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

contract PythAdapter is IOracleAdapter {
    IPyth public immutable pyth;
    bytes32 public immutable priceId;

    constructor(address _pyth, bytes32 _priceId) { pyth = IPyth(_pyth); priceId = _priceId; }

    function getPrice(address) external view override returns (uint256 price, uint256 updatedAt) {
        PythStructs.Price memory p = pyth.getPriceNoOlderThan(priceId, 3600);
        require(p.price > 0, "Invalid price");
        int32 expo = p.expo;
        price = expo >= 0
            ? uint256(uint64(p.price)) * 10 ** (18 + uint32(expo))
            : uint256(uint64(p.price)) * 10 ** 18 / 10 ** uint32(-expo);
        updatedAt = p.publishTime;
    }
}
```

### L2 Sequencer Uptime Feed

```solidity
modifier sequencerHealthy() {
    (, int256 answer, uint256 startedAt, , ) = sequencerUptimeFeed.latestRoundData();
    require(answer == 0, "SME: sequencer down");
    require(block.timestamp - startedAt > GRACE_PERIOD, "SME: grace period not elapsed");
    _;
}
```

### Proof of Reserve

```solidity
function checkReserves(uint256 additionalMint) public view returns (bool) {
    (, int256 reserves, , uint256 updatedAt, ) = porFeed.latestRoundData();
    require(reserves > 0, "SME: invalid PoR");
    require(block.timestamp - updatedAt <= POR_STALENESS, "SME: stale PoR");
    return uint256(reserves) >= token.totalSupply() + additionalMint;
}
```

---

## Monitoring & Alerting

### Required Monitoring Endpoints

| Metric | Alert Threshold | Severity |
|--------|----------------|----------|
| Oracle staleness | > 80% of threshold | WARNING |
| Oracle staleness | > 100% of threshold | CRITICAL |
| Price deviation (primary vs secondary) | > 3% | WARNING |
| Price deviation (primary vs secondary) | > 5% | CRITICAL |
| Oracle round completeness | answeredInRound < roundId | CRITICAL |
| Sequencer status (L2) | Status = 1 (down) | CRITICAL |
| Reserve ratio | < 105% | WARNING |
| Reserve ratio | < 100% | CRITICAL |
| Gas price for oracle update | > 200 gwei | WARNING |
| Oracle contract upgrade detected | Any proxy upgrade | CRITICAL |

### Recommended Monitoring Stack

- **Tenderly Alerts** or **OpenZeppelin Defender Sentinels** for on-chain monitoring
- **Grafana + Prometheus** for metrics dashboards
- **PagerDuty / OpsGenie** for incident routing
- **Custom keeper bots** for proactive oracle health checks

### Oracle Upgrade Monitoring

Monitor these events on oracle proxy contracts:

1. `Upgraded(address implementation)` events
2. Admin/owner changes
3. Feed deprecation announcements from oracle providers
4. Network-specific registry changes (Chainlink Feed Registry)

---

## Appendix: Oracle Feed Addresses

### Ethereum Mainnet (Chainlink)

| Feed | Address | Decimals |
|------|---------|----------|
| ETH/USD | `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419` | 8 |
| BTC/USD | `0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c` | 8 |
| USDC/USD | `0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6` | 8 |
| DAI/USD | `0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9` | 8 |
| L2 Sequencer (Arbitrum) | `0xFdB631F5EE196F0ed6FAa767959853A9F217697D` | 0 |

> NOTE: Always verify addresses against official Chainlink documentation before deployment.
