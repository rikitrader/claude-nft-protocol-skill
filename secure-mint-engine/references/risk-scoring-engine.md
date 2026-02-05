# Risk Scoring Engine Reference

## Overview

The Risk Scoring Engine provides real-time, quantitative risk assessment for oracle-gated token minting protocols. It aggregates multiple risk metrics into a composite score that triggers automated responses and emergency procedures.

## Core Principles

- **Continuous Monitoring**: Risk scores are calculated in real-time based on live data feeds
- **Multi-Dimensional Analysis**: No single metric dominates; composite scoring provides holistic view
- **Automated Response**: Risk levels trigger programmatic actions without human intervention
- **Transparent Methodology**: All calculations, weights, and thresholds are publicly auditable

---

## Risk Metrics

### 1. Oracle Freshness Score (Weight: 15%)

**Purpose**: Measures the recency and reliability of oracle data feeds.

**Calculation Formula**:
```
OFS = 100 - (age_minutes / max_age_minutes × 100)

where:
- age_minutes = current_time - last_oracle_update
- max_age_minutes = 30 (configurable threshold)
```

**Thresholds**:
- **Green (80-100)**: Oracle updated within 10 minutes
- **Yellow (60-79)**: Oracle updated 10-20 minutes ago
- **Red (40-59)**: Oracle updated 20-30 minutes ago
- **Critical (0-39)**: Oracle updated >30 minutes ago or unresponsive

**Data Source**: Direct oracle contract queries (Chainlink, Band Protocol, API3)

**Example Implementation**:
```solidity
uint256 lastUpdate = IOracle(oracleAddress).latestTimestamp();
uint256 ageMinutes = (block.timestamp - lastUpdate) / 60;
uint256 oracleScore = ageMinutes >= 30 ? 0 : 100 - (ageMinutes * 100 / 30);
```

---

### 2. Collateral Ratio Score (Weight: 20%)

**Purpose**: Ensures backing assets exceed token supply at all times.

**Calculation Formula**:
```
CRS = min(100, (total_backing_usd / total_supply_usd) × 100)

where:
- total_backing_usd = sum of all backing asset values in USD
- total_supply_usd = circulating supply × current token price
```

**Thresholds**:
- **Green (100+)**: Collateral ratio ≥ 110% (over-collateralized)
- **Yellow (90-99)**: Collateral ratio 100-109% (adequately collateralized)
- **Red (80-89)**: Collateral ratio 90-99% (under-collateralized)
- **Critical (<80)**: Collateral ratio <90% (severely under-collateralized)

**Data Source**: On-chain reserve contract + oracle price feeds

**Example Implementation**:
```go
func CalculateCollateralScore(backingUSD, supplyUSD float64) float64 {
    ratio := (backingUSD / supplyUSD) * 100
    if ratio >= 110 {
        return 100
    }
    if ratio < 90 {
        return (ratio / 90) * 80 // Scale to 0-80 range
    }
    return 80 + (ratio - 90) * 2 // Scale 90-110 to 80-100
}
```

---

### 3. Liquidity Depth Score (Weight: 12%)

**Purpose**: Measures available liquidity to absorb large redemptions without price impact.

**Calculation Formula**:
```
LDS = min(100, (total_dex_liquidity_usd / (total_supply_usd × 0.1)) × 100)

where:
- total_dex_liquidity_usd = sum of liquidity across all DEX pools
- 0.1 = assumption that 10% of supply could need immediate redemption
```

**Thresholds**:
- **Green (80-100)**: Liquidity ≥ 10% of total supply
- **Yellow (60-79)**: Liquidity 5-10% of total supply
- **Red (40-59)**: Liquidity 2-5% of total supply
- **Critical (0-39)**: Liquidity <2% of total supply

**Data Source**: DeFi Llama TVL API, DEX subgraphs (Uniswap, SushiSwap, Curve)

---

### 4. Volatility Score (Weight: 10%)

**Purpose**: Tracks price volatility of backing assets to detect instability.

**Calculation Formula**:
```
VS = 100 - (standard_deviation_7d / mean_price_7d × 100)

where:
- standard_deviation_7d = 7-day rolling standard deviation of backing asset prices
- mean_price_7d = 7-day rolling average price
```

**Thresholds**:
- **Green (80-100)**: Volatility <5%
- **Yellow (60-79)**: Volatility 5-10%
- **Red (40-59)**: Volatility 10-20%
- **Critical (0-39)**: Volatility >20%

**Data Source**: Historical price feeds from Chainlink, CoinGecko, or proprietary TWAP

---

### 5. Governance Activity Score (Weight: 8%)

**Purpose**: Measures the health and responsiveness of protocol governance.

**Calculation Formula**:
```
GAS = (active_voters / total_token_holders × 50) + (proposals_30d / expected_proposals × 50)

where:
- active_voters = unique voters in last 30 days
- total_token_holders = total governance token holders
- proposals_30d = proposals submitted in last 30 days
- expected_proposals = baseline threshold (e.g., 4 per month)
```

**Thresholds**:
- **Green (80-100)**: >20% voter participation, regular proposals
- **Yellow (60-79)**: 10-20% participation, occasional proposals
- **Red (40-59)**: 5-10% participation, rare proposals
- **Critical (0-39)**: <5% participation, governance stagnation

**Data Source**: Snapshot API, Tally, on-chain governance contracts

---

### 6. Bridge Security Score (Weight: 10%)

**Purpose**: Assesses the security posture of cross-chain bridges used for backing assets.

**Calculation Formula**:
```
BSS = (bridge_uptime_pct × 0.3) + (audits_passed × 20) + ((100 - incident_count_90d × 10) × 0.5)

where:
- bridge_uptime_pct = % uptime in last 30 days
- audits_passed = number of completed security audits (capped at 5)
- incident_count_90d = number of security incidents in last 90 days
```

**Thresholds**:
- **Green (80-100)**: Multiple audits, 99%+ uptime, zero incidents
- **Yellow (60-79)**: At least one audit, 95-99% uptime, minor incidents
- **Red (40-59)**: Unaudited or <95% uptime, moderate incidents
- **Critical (0-39)**: Known exploits, extended downtime, no audits

**Data Source**: Rekt.news, L2Beat, bridge status APIs (Wormhole, LayerZero, etc.)

---

### 7. Smart Contract Risk Score (Weight: 12%)

**Purpose**: Evaluates the security of protocol smart contracts.

**Calculation Formula**:
```
SCRS = (audits_completed × 20) + (bug_bounty_size_usd / 1_000_000 × 20) + (days_since_deployment / 365 × 30) + (no_critical_bugs × 30)

where:
- audits_completed = number of audits by reputable firms (capped at 5)
- bug_bounty_size_usd = maximum bug bounty payout
- days_since_deployment = contract age in days
- no_critical_bugs = binary flag (30 points if no critical bugs found)
```

**Thresholds**:
- **Green (80-100)**: Multiple audits, large bounty, >1 year history, clean record
- **Yellow (60-79)**: 1-2 audits, moderate bounty, 6-12 months history
- **Red (40-59)**: Single audit or new contract (<6 months)
- **Critical (0-39)**: Unaudited, known vulnerabilities, or recently exploited

**Data Source**: Audit reports (Certik, Trail of Bits, OpenZeppelin), Immunefi, blockchain explorers

---

### 8. Market Sentiment Score (Weight: 8%)

**Purpose**: Gauges overall market sentiment and potential for panic-driven redemptions.

**Calculation Formula**:
```
MSS = (social_sentiment_score × 0.4) + (trading_volume_ratio × 0.3) + ((100 - fear_greed_index) × 0.3)

where:
- social_sentiment_score = aggregated sentiment from Twitter, Reddit, Discord (0-100)
- trading_volume_ratio = (current_24h_volume / average_30d_volume) × 50, capped at 100
- fear_greed_index = market fear/greed index (0=fear, 100=greed), inverted
```

**Thresholds**:
- **Green (80-100)**: Positive sentiment, normal volume, greed phase
- **Yellow (60-79)**: Neutral sentiment, slightly elevated volume
- **Red (40-59)**: Negative sentiment, high volume, fear phase
- **Critical (0-39)**: Extreme fear, volume spikes, panic indicators

**Data Source**: LunarCrush, Alternative.me Fear & Greed Index, DEX volume aggregators

---

### 9. Regulatory Risk Score (Weight: 5%)

**Purpose**: Monitors regulatory developments that could impact protocol operations.

**Calculation Formula**:
```
RRS = 100 - (active_regulatory_threats × 20) - (jurisdictions_banned × 15)

where:
- active_regulatory_threats = number of pending regulations targeting protocol type
- jurisdictions_banned = number of major jurisdictions where protocol is restricted
```

**Thresholds**:
- **Green (80-100)**: No active threats, operating in compliant jurisdictions
- **Yellow (60-79)**: Minor regulatory attention, 1-2 jurisdiction concerns
- **Red (40-59)**: Active investigations or proposed regulations
- **Critical (0-39)**: Enforcement actions, multiple jurisdiction bans

**Data Source**: Regulatory news feeds, legal database subscriptions, government APIs

---

## Composite Risk Score Formula

The **Composite Risk Score (CRS)** is the weighted average of all metrics:

```
CRS = (OFS × 0.15) + (CRS × 0.20) + (LDS × 0.12) + (VS × 0.10) + (GAS × 0.08) + (BSS × 0.10) + (SCRS × 0.12) + (MSS × 0.08) + (RRS × 0.05)

where weights sum to 1.00 (100%)
```

### Implementation Example

```go
type RiskMetrics struct {
    OracleFreshness    float64 `json:"oracle_freshness"`
    CollateralRatio    float64 `json:"collateral_ratio"`
    LiquidityDepth     float64 `json:"liquidity_depth"`
    Volatility         float64 `json:"volatility"`
    GovernanceActivity float64 `json:"governance_activity"`
    BridgeSecurity     float64 `json:"bridge_security"`
    SmartContractRisk  float64 `json:"smart_contract_risk"`
    MarketSentiment    float64 `json:"market_sentiment"`
    RegulatoryRisk     float64 `json:"regulatory_risk"`
}

func (m *RiskMetrics) CompositeScore() float64 {
    return (m.OracleFreshness * 0.15) +
           (m.CollateralRatio * 0.20) +
           (m.LiquidityDepth * 0.12) +
           (m.Volatility * 0.10) +
           (m.GovernanceActivity * 0.08) +
           (m.BridgeSecurity * 0.10) +
           (m.SmartContractRisk * 0.12) +
           (m.MarketSentiment * 0.08) +
           (m.RegulatoryRisk * 0.05)
}
```

---

## Risk Level Mapping

| Risk Level | Score Range | Color Code | Description |
|------------|-------------|------------|-------------|
| **LOW** | 80-100 | 🟢 Green | All systems healthy, normal operations |
| **MEDIUM** | 60-79 | 🟡 Yellow | Elevated risk, monitoring increased |
| **HIGH** | 40-59 | 🟠 Orange | Significant risk, automated restrictions active |
| **CRITICAL** | 0-39 | 🔴 Red | Emergency protocols engaged, minting halted |

---

## Alert Triggers and Response Actions

### LOW Risk (80-100)

**Alerts**:
- None (normal logging only)

**Actions**:
- Continue normal operations
- Standard monitoring interval (every 5 minutes)

---

### MEDIUM Risk (60-79)

**Alerts**:
- Dashboard notification
- Email to risk management team

**Actions**:
- Increase monitoring frequency (every 1 minute)
- Log detailed metric breakdown
- Notify governance forum
- No operational restrictions

---

### HIGH Risk (40-59)

**Alerts**:
- Dashboard critical warning
- Email + SMS to risk management and dev team
- Discord/Telegram alerts to community

**Actions**:
- Reduce mint rate limit by 50%
- Increase redemption priority
- Require multi-sig approval for large mints (>$100k)
- Publish risk report to protocol website
- Emergency governance proposal triggered

---

### CRITICAL Risk (0-39)

**Alerts**:
- All channels: Dashboard, Email, SMS, PagerDuty
- Public protocol status page updated
- Social media announcement

**Actions**:
- **HALT ALL MINTING** immediately
- Activate EmergencyPause contract
- Escalate to core development team
- Publish detailed incident report within 1 hour
- Notify all exchange partners
- Prepare emergency governance vote for recovery

---

## Integration with EmergencyPause Contract

The Risk Scoring Engine automatically triggers the `EmergencyPause` contract when **Composite Risk Score < 40** (CRITICAL level).

### EmergencyPause Interface

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEmergencyPause {
    /// @notice Pause all minting operations
    /// @param reason Encoded reason for pause (see PAUSE_REASONS)
    /// @param riskScore Current composite risk score (0-100)
    function pauseMinting(bytes32 reason, uint8 riskScore) external;

    /// @notice Resume minting after emergency is resolved
    /// @param authorizer Address of multi-sig that authorized resume
    function resumeMinting(address authorizer) external;

    /// @notice Check if minting is currently paused
    function isMintingPaused() external view returns (bool);

    /// @notice Get pause details
    function getPauseDetails() external view returns (
        bool isPaused,
        uint256 pausedAt,
        bytes32 reason,
        uint8 triggerScore
    );
}

/// Pause reason codes
bytes32 constant PAUSE_ORACLE_STALE = keccak256("ORACLE_STALE");
bytes32 constant PAUSE_UNDERCOLLATERALIZED = keccak256("UNDERCOLLATERALIZED");
bytes32 constant PAUSE_LIQUIDITY_CRISIS = keccak256("LIQUIDITY_CRISIS");
bytes32 constant PAUSE_COMPOSITE_CRITICAL = keccak256("COMPOSITE_CRITICAL");
bytes32 constant PAUSE_MANUAL_INTERVENTION = keccak256("MANUAL_INTERVENTION");
```

### Auto-Escalation Logic

```go
func (e *RiskEngine) CheckAndEscalate(metrics RiskMetrics) error {
    compositeScore := metrics.CompositeScore()

    if compositeScore < 40 {
        // Determine primary failure reason
        reason := e.determinePauseReason(metrics)

        // Call EmergencyPause contract
        tx, err := e.pauseContract.PauseMinting(
            reason,
            uint8(compositeScore),
        )
        if err != nil {
            return fmt.Errorf("failed to pause minting: %w", err)
        }

        // Log incident
        e.logger.Critical("EMERGENCY_PAUSE_TRIGGERED", map[string]interface{}{
            "tx_hash": tx.Hash(),
            "reason": reason,
            "composite_score": compositeScore,
            "metrics": metrics,
        })

        // Trigger all alert channels
        e.alertManager.SendCriticalAlert(compositeScore, metrics)
    }

    return nil
}

func (e *RiskEngine) determinePauseReason(metrics RiskMetrics) [32]byte {
    if metrics.OracleFreshness < 40 {
        return PAUSE_ORACLE_STALE
    }
    if metrics.CollateralRatio < 40 {
        return PAUSE_UNDERCOLLATERALIZED
    }
    if metrics.LiquidityDepth < 40 {
        return PAUSE_LIQUIDITY_CRISIS
    }
    return PAUSE_COMPOSITE_CRITICAL
}
```

---

## Monitoring Dashboard

### Key Performance Indicators (KPIs)

1. **Current Composite Score**: Large, color-coded display
2. **Metric Breakdown**: 9 individual scores with trend arrows
3. **Historical Graph**: 24-hour score history
4. **Alert Log**: Recent alerts with timestamps and actions taken
5. **Time to Recovery**: When in elevated risk, estimated time to return to LOW

### Dashboard Implementation

```javascript
// Real-time WebSocket updates
const ws = new WebSocket('wss://risk-engine.protocol.com/stream');

ws.onmessage = (event) => {
    const riskData = JSON.parse(event.data);
    updateDashboard(riskData);

    if (riskData.compositeScore < 40) {
        triggerEmergencyUI();
    }
};

function updateDashboard(data) {
    document.getElementById('composite-score').textContent = data.compositeScore.toFixed(2);
    document.getElementById('composite-score').className = getRiskClass(data.compositeScore);

    // Update individual metrics
    updateMetric('oracle', data.oracleFreshness);
    updateMetric('collateral', data.collateralRatio);
    // ... etc
}
```

---

## Testing and Validation

### Backtesting Protocol

Run historical data through risk engine to validate thresholds:

```bash
# Backtest against historical crisis events
go run cmd/backtest/main.go \
  --event "UST_DEPEG_2022" \
  --start "2022-05-07" \
  --end "2022-05-12"

# Expected: Should trigger CRITICAL alert before major collapse
```

### Stress Testing

```go
func TestRiskEngine_USTDepegScenario(t *testing.T) {
    engine := NewRiskEngine()

    // Simulate UST depeg conditions
    metrics := RiskMetrics{
        OracleFreshness:    75.0, // Oracle still working
        CollateralRatio:    35.0, // CRITICAL: backing collapsed
        LiquidityDepth:     20.0, // CRITICAL: liquidity fled
        Volatility:         10.0, // Extreme volatility
        GovernanceActivity: 90.0, // High activity (panic proposals)
        BridgeSecurity:     80.0, // Bridges working
        SmartContractRisk:  85.0, // Contracts fine
        MarketSentiment:    15.0, // CRITICAL: extreme fear
        RegulatoryRisk:     70.0, // Some regulatory attention
    }

    score := metrics.CompositeScore()
    assert.Less(t, score, 40.0, "Should trigger CRITICAL level")

    // Verify emergency pause would activate
    err := engine.CheckAndEscalate(metrics)
    assert.NoError(t, err)
    assert.True(t, engine.IsPaused())
}
```

---

## Recovery Procedures

### Exiting CRITICAL Risk State

1. **Root Cause Analysis**: Identify which metric(s) triggered CRITICAL
2. **Remediation Plan**: Execute fixes for failing metrics
3. **Validation**: Confirm metrics return to acceptable ranges
4. **Multi-Sig Resume**: Require 3-of-5 multi-sig to call `resumeMinting()`
5. **Gradual Restart**: Resume minting with reduced limits initially
6. **Monitoring Period**: 48-hour elevated monitoring after resume

### Multi-Sig Resume Requirement

```solidity
contract EmergencyPause is IEmergencyPause {
    address public immutable multiSig;
    uint8 public constant MIN_COMPOSITE_SCORE = 60;

    function resumeMinting(address authorizer) external override {
        require(msg.sender == multiSig, "Only multi-sig can resume");
        require(isPaused, "Not currently paused");

        // Fetch current risk score from oracle
        uint8 currentScore = IRiskOracle(riskOracle).getCompositeScore();
        require(currentScore >= MIN_COMPOSITE_SCORE, "Risk still too high");

        isPaused = false;
        resumedAt = block.timestamp;
        resumeAuthorizer = authorizer;

        emit MintingResumed(authorizer, currentScore, block.timestamp);
    }
}
```

---

## Conclusion

The Risk Scoring Engine provides a robust, quantitative framework for assessing protocol health in real-time. By combining multiple dimensions of risk into a single composite score, it enables both human operators and automated systems to make informed decisions about protocol safety.

**Key Takeaways**:
- Multi-metric approach prevents single-point-of-failure in risk assessment
- Automated escalation ensures rapid response to critical situations
- Transparent methodology builds user trust and enables auditability
- Integration with EmergencyPause contract provides failsafe mechanism

**Next Steps**:
- Review [auto-elimination-engine.md](./auto-elimination-engine.md) for programmatic elimination rules
- See [live-data-hooks-engine.md](./live-data-hooks-engine.md) for data feed integration
- Consult [monetary-theory-foundations.md](./monetary-theory-foundations.md) for theoretical backing
