# Tokenomics Design Template

## Basic Parameters

| Parameter | Value | Notes |
|-----------|-------|-------|
| Token Name | | |
| Symbol | | |
| Total Supply | 1,000,000,000 | Fixed, immutable |
| Decimals | 9 | Solana standard |
| Chain | Solana | Primary |

## Distribution

```
┌────────────────────────────────────────────────────────────┐
│                    TOKEN DISTRIBUTION                       │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  ████████████████████████████████████████████████  70%     │
│  Liquidity Pool                                             │
│                                                             │
│  ██████████████████  15%                                   │
│  Community / Airdrop                                        │
│                                                             │
│  ████████████  10%                                         │
│  Treasury DAO                                               │
│                                                             │
│  ██████  5%                                                │
│  Team (Vested)                                              │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

### Distribution Breakdown

| Allocation | Percentage | Tokens | Unlock Schedule |
|------------|------------|--------|-----------------|
| Liquidity Pool | 70% | 700,000,000 | Immediate (LP locked) |
| Community/Airdrop | 15% | 150,000,000 | 50% TGE, 50% over 6mo |
| Treasury DAO | 10% | 100,000,000 | Governance controlled |
| Team | 5% | 50,000,000 | 12mo cliff, 24mo vest |

## Vesting Schedules

### Team Vesting

```
Month 0-12:   ████████████████░░░░░░░░░░░░░░░░  0% (Cliff)
Month 12-24:  ████████████████████████░░░░░░░░  50% Linear
Month 24-36:  ████████████████████████████████  100%
```

### Treasury Release (Example)

| Quarter | Available | Cumulative |
|---------|-----------|------------|
| Q1 | 10M | 10M |
| Q2 | 15M | 25M |
| Q3 | 25M | 50M |
| Q4+ | Governance | - |

## Burn Mechanics

### Automatic Burns

| Trigger | Burn Rate | Notes |
|---------|-----------|-------|
| Every Trade | 1% (100 bps) | Taken from transaction |
| Volume Milestone | 10M per 100M vol | Treasury reserve |
| NFT Mint | 1000 tokens | Per NFT |

### Burn Projection

```
Year 1 Projection (Conservative):
- Trade burns: ~50M tokens (5% supply)
- Milestone burns: ~30M tokens
- Activity burns: ~20M tokens
- Total Year 1: ~100M tokens (10% supply)

Resulting Supply: 900M tokens
```

## Treasury Economics

### Revenue Sources

| Source | Estimated Annual | Notes |
|--------|------------------|-------|
| NFT Sales | $500K-2M | Primary collection + derivatives |
| Merchandise | $100K-500K | Physical + digital |
| Partnerships | $200K-1M | Sponsorships, collaborations |
| Protocol Fees | Variable | Future utility features |

### Treasury Allocation Policy

| Category | Max % | Purpose |
|----------|-------|---------|
| Marketing | 40% | Growth, KOLs, campaigns |
| Development | 30% | Protocol improvements |
| Buyback & Burn | 20% | Price support, deflation |
| Reserve | 10% | Emergency, opportunities |

## Liquidity Strategy

### Initial Pool

| Metric | Value |
|--------|-------|
| Pair | TOKEN/USDC |
| Initial Token | 700,000,000 (70%) |
| Initial USDC | $100,000 |
| Initial Price | $0.000143 |
| Initial MCap | $143,000 |
| LP Lock | 12 months minimum |
| Script | `scripts/dex/raydium_lp.sh` |

### Liquidity Targets

| Market Cap | Target LP Depth | Slippage (10K swap) |
|------------|-----------------|---------------------|
| $1M | $200K | ~2.5% |
| $10M | $1M | ~0.5% |
| $100M | $5M | ~0.1% |

## Governance

### Phase 1: Centralized (Month 0-6)

- Team multi-sig controls treasury
- Community feedback via Telegram/Discord
- Transparent spending reports

### Phase 2: Hybrid (Month 6-12)

- Snapshot voting for major decisions
- Community proposals
- Team retains veto for security

### Phase 3: DAO (Month 12+)

- On-chain governance
- Token-weighted voting
- Full treasury control to DAO

## Risk Factors

### Supply Risks

| Risk | Mitigation |
|------|------------|
| Infinite mint | Mint authority revoked |
| Team dump | 12mo cliff + 24mo vest |
| Whale concentration | Distribution to 10+ wallets |

### Liquidity Risks

| Risk | Mitigation |
|------|------------|
| LP rug | LP locked/burned |
| Low liquidity | Treasury LP support |
| DEX attack | Emergency pause |

### Governance Risks

| Risk | Mitigation |
|------|------------|
| Treasury drain | Daily spend caps |
| Hostile takeover | Time-locks on changes |
| Apathy | Incentivized voting |

## Key Metrics to Track

### Health Indicators

| Metric | Healthy Range | Warning |
|--------|---------------|---------|
| Holder count | Growing | Declining |
| Unique daily wallets | >100 | <50 |
| LP/MCap ratio | >10% | <5% |
| Treasury runway | >12 months | <6 months |

### Growth Indicators

| Metric | Target |
|--------|--------|
| 30-day volume | >$1M |
| Social mentions | >1000/week |
| Developer activity | Weekly commits |
| Partnership announcements | Monthly |

## Comparable Analysis

| Project | Supply | LP % | Team % | Burns |
|---------|--------|------|--------|-------|
| BONK | 100T | Variable | 5% | Yes |
| WIF | 1B | ~60% | 0% | No |
| PEPE | 420T | Variable | 0% | Yes |
| **Ours** | 1B | 70% | 5% | Yes |

## Summary

```
┌─────────────────────────────────────────────────────────────┐
│                 TOKENOMICS SUMMARY                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Supply:        1,000,000,000 (FIXED)                        │
│  Chain:         Solana (Primary)                             │
│  LP:            70% (Locked 12mo+)                           │
│  Team:          5% (12mo cliff, 24mo vest)                   │
│  Burns:         1% per trade + milestones                    │
│  Governance:    Multi-sig → Snapshot → On-chain DAO          │
│                                                              │
│  ANTI-RUG FEATURES:                                          │
│  ✅ Mint authority revoked                                   │
│  ✅ LP locked/burned                                         │
│  ✅ Team tokens vested                                       │
│  ✅ Treasury multi-sig                                       │
│  ✅ Emergency controls (time-limited)                        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```
