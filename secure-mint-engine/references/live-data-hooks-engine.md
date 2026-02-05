# Live Data Hooks Engine

> Integration specifications for real-time data feeds that power the SecureMintEngine's
> Market Intelligence Engine and ongoing monitoring systems.

---

## Table of Contents

1. [Overview](#overview)
2. [DeFiLlama TVL API](#defillama-tvl-api)
3. [L2Beat Bridge Data](#l2beat-bridge-data)
4. [Rekt.news Exploit Feed](#rektnews-exploit-feed)
5. [CoinGecko / CoinMarketCap Price Feeds](#coingecko--coinmarketcap-price-feeds)
6. [On-Chain RPC Queries](#on-chain-rpc-queries)
7. [Webhook Configuration](#webhook-configuration)
8. [Polling Intervals & Caching](#polling-intervals--caching)
9. [Error Handling & Fallbacks](#error-handling--fallbacks)

---

## Overview

The Live Data Hooks Engine provides real-time and near-real-time data to:
- Phase 0 Market Intelligence Engine (chain evaluation)
- Risk Scoring Engine (ongoing risk assessment)
- Monitoring dashboards (operational health)
- Auto-Elimination Engine (programmatic fail detection)

### Data Flow Architecture

```
External APIs / RPC Nodes
         |
         v
+-------------------+
| Data Collector    |  (Polling + Webhooks)
| - Rate limiting   |
| - Retry logic     |
| - Normalization   |
+-------------------+
         |
         v
+-------------------+
| Cache Layer       |  (Redis / In-memory)
| - TTL per source  |
| - Stale detection |
+-------------------+
         |
         v
+-------------------+
| Consumer Layer    |
| - MI Engine       |
| - Risk Scoring    |
| - Monitoring      |
| - Elimination     |
+-------------------+
```

---

## DeFiLlama TVL API

### Endpoints

| Endpoint | Description | Rate Limit |
|----------|------------|-----------|
| `GET /v2/chains` | TVL for all chains | 300 req/5min |
| `GET /v2/historicalChainTvl/{chain}` | Historical TVL for a chain | 300 req/5min |
| `GET /protocol/{protocol}` | Protocol-specific TVL | 300 req/5min |
| `GET /v2/historicalChainTvl` | Global TVL history | 300 req/5min |

### Integration Code

```typescript
interface ChainTVL {
  gecko_id: string;
  tvl: number;
  tokenSymbol: string;
  cmcId: string;
  name: string;
  chainId: number;
}

interface DeFiLlamaConfig {
  baseUrl: string;
  cacheTTL: number;     // seconds
  retryAttempts: number;
  retryDelay: number;   // ms
}

const DEFAULT_CONFIG: DeFiLlamaConfig = {
  baseUrl: "https://api.llama.fi",
  cacheTTL: 300,        // 5 minutes
  retryAttempts: 3,
  retryDelay: 1000,
};

async function getChainTVL(chain: string, config = DEFAULT_CONFIG): Promise<number> {
  const cacheKey = `defillama:chain:${chain}:tvl`;
  const cached = await cache.get(cacheKey);
  if (cached) return cached;

  const response = await fetchWithRetry(
    `${config.baseUrl}/v2/chains`,
    config.retryAttempts,
    config.retryDelay,
  );

  const chains: ChainTVL[] = await response.json();
  const target = chains.find(c => c.name.toLowerCase() === chain.toLowerCase());

  if (!target) throw new Error(`Chain not found: ${chain}`);

  await cache.set(cacheKey, target.tvl, config.cacheTTL);
  return target.tvl;
}

async function getProtocolTVL(protocol: string): Promise<{
  tvl: number;
  chainTvls: Record<string, number>;
  mcap: number;
}> {
  const response = await fetchWithRetry(
    `${DEFAULT_CONFIG.baseUrl}/protocol/${protocol}`,
    3, 1000,
  );
  const data = await response.json();
  return {
    tvl: data.tvl,
    chainTvls: data.chainTvls,
    mcap: data.mcap,
  };
}
```

### Data Points Extracted

- Chain TVL (current)
- Chain TVL (30-day trend)
- Protocol TVL breakdown by chain
- DEX TVL per chain
- Stablecoin TVL per chain

---

## L2Beat Bridge Data

### Endpoints

| Endpoint | Description | Rate Limit |
|----------|------------|-----------|
| `GET /api/scaling/tvl` | L2 TVL data | Public, reasonable use |
| `GET /api/scaling/summary` | L2 risk summaries | Public, reasonable use |
| `GET /api/scaling/activity` | L2 transaction activity | Public, reasonable use |

### Integration Code

```typescript
interface L2BeatProject {
  id: string;
  name: string;
  slug: string;
  tvl: number;
  riskView: {
    stateValidation: string;  // e.g., "Fraud proofs"
    dataAvailability: string; // e.g., "On chain"
    exitWindow: string;       // e.g., "7d"
    sequencerFailure: string; // e.g., "Enqueue via L1"
    proposerFailure: string;  // e.g., "Self propose"
  };
  stage: "Stage 0" | "Stage 1" | "Stage 2";
  technology: string;
}

async function getL2RiskAssessment(l2Name: string): Promise<{
  stage: string;
  riskView: L2BeatProject["riskView"];
  tvl: number;
  bridgeScore: number;
}> {
  const response = await fetchWithRetry(
    "https://l2beat.com/api/scaling/summary",
    3, 1000,
  );
  const data = await response.json();
  const project = data.projects.find(
    (p: L2BeatProject) => p.name.toLowerCase() === l2Name.toLowerCase()
  );

  if (!project) throw new Error(`L2 not found: ${l2Name}`);

  // Calculate bridge score based on stage and risk view
  let bridgeScore = 0;
  switch (project.stage) {
    case "Stage 2": bridgeScore = 100; break;
    case "Stage 1": bridgeScore = 80; break;
    case "Stage 0": bridgeScore = 60; break;
    default: bridgeScore = 40;
  }

  // Adjust for specific risk factors
  if (project.riskView.stateValidation.includes("No proof")) bridgeScore -= 20;
  if (project.riskView.dataAvailability !== "On chain") bridgeScore -= 10;
  if (project.riskView.exitWindow === "None") bridgeScore -= 15;

  return {
    stage: project.stage,
    riskView: project.riskView,
    tvl: project.tvl,
    bridgeScore: Math.max(0, bridgeScore),
  };
}
```

### Data Points Extracted

- L2 stage classification (Stage 0/1/2)
- Bridge risk factors (state validation, DA, exit window)
- L2 TVL and activity metrics
- Technology type (Optimistic, ZK, Validium)

---

## Rekt.news Exploit Feed

### Data Source

Rekt.news does not have a public API. Data is collected via:
1. RSS feed parsing
2. Web scraping (respectful, with caching)
3. Curated database (maintained manually with automated alerts)

### Integration Code

```typescript
interface ExploitRecord {
  date: string;          // ISO 8601
  protocol: string;
  chain: string;
  amount_usd: number;
  type: string;          // "flash_loan" | "reentrancy" | "oracle" | "bridge" | "admin_key" | "other"
  url: string;           // rekt.news article URL
  postmortem_url?: string;
  recovered_usd?: number;
}

interface ExploitDatabase {
  last_updated: string;
  exploits: ExploitRecord[];
}

// Maintained as a JSON file, updated via CI job
const EXPLOIT_DB_PATH = "./data/exploit-database.json";

function getExploitsForChain(chain: string, db: ExploitDatabase): {
  total_count: number;
  total_lost_usd: number;
  last_exploit_days: number;
  recent_exploits: ExploitRecord[];  // last 12 months
  risk_score: number;
} {
  const chainExploits = db.exploits.filter(
    e => e.chain.toLowerCase() === chain.toLowerCase()
  );

  const now = new Date();
  const recentCutoff = new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000);
  const recent = chainExploits.filter(e => new Date(e.date) >= recentCutoff);

  const lastExploit = chainExploits.length > 0
    ? Math.max(...chainExploits.map(e => new Date(e.date).getTime()))
    : 0;
  const daysSinceLastExploit = lastExploit > 0
    ? Math.floor((now.getTime() - lastExploit) / (24 * 60 * 60 * 1000))
    : 9999;

  // Calculate risk score
  let riskScore = 100;
  if (daysSinceLastExploit < 30) riskScore = 10;
  else if (daysSinceLastExploit < 90) riskScore = 35;
  else if (daysSinceLastExploit < 180) riskScore = 55;
  else if (daysSinceLastExploit < 365) riskScore = 75;
  else if (daysSinceLastExploit < 730) riskScore = 90;

  // Penalty for multiple recent exploits
  if (recent.length > 3) riskScore -= 20;
  else if (recent.length > 1) riskScore -= 10;

  return {
    total_count: chainExploits.length,
    total_lost_usd: chainExploits.reduce((sum, e) => sum + e.amount_usd, 0),
    last_exploit_days: daysSinceLastExploit,
    recent_exploits: recent,
    risk_score: Math.max(0, riskScore),
  };
}
```

### Update Frequency

- **Automated check**: Every 6 hours
- **Manual review**: Daily by security team
- **Alert trigger**: Any new entry > $1M triggers immediate notification

---

## CoinGecko / CoinMarketCap Price Feeds

### CoinGecko API

| Endpoint | Description | Rate Limit |
|----------|------------|-----------|
| `GET /api/v3/simple/price` | Current prices | 10-50 req/min (plan dependent) |
| `GET /api/v3/coins/{id}/market_chart` | Historical prices | 10-50 req/min |
| `GET /api/v3/coins/{id}/market_chart/range` | Price range | 10-50 req/min |

### Integration Code

```typescript
interface PriceData {
  usd: number;
  usd_24h_change: number;
  usd_24h_vol: number;
  usd_market_cap: number;
  last_updated_at: number;
}

interface VolatilityData {
  period_days: number;
  annualized_volatility: number;
  max_drawdown: number;
  daily_returns: number[];
}

async function getCurrentPrice(coinId: string): Promise<PriceData> {
  const cacheKey = `coingecko:price:${coinId}`;
  const cached = await cache.get(cacheKey);
  if (cached) return cached;

  const response = await fetchWithRetry(
    `https://api.coingecko.com/api/v3/simple/price?ids=${coinId}&vs_currencies=usd&include_24hr_change=true&include_24hr_vol=true&include_market_cap=true&include_last_updated_at=true`,
    3, 2000,
  );
  const data = await response.json();
  const price = data[coinId];

  await cache.set(cacheKey, price, 60); // 1 minute cache
  return price;
}

async function calculateVolatility(coinId: string, days: number): Promise<VolatilityData> {
  const response = await fetchWithRetry(
    `https://api.coingecko.com/api/v3/coins/${coinId}/market_chart?vs_currency=usd&days=${days}&interval=daily`,
    3, 2000,
  );
  const data = await response.json();
  const prices = data.prices.map((p: [number, number]) => p[1]);

  // Calculate daily returns
  const dailyReturns: number[] = [];
  for (let i = 1; i < prices.length; i++) {
    dailyReturns.push((prices[i] / prices[i - 1]) - 1);
  }

  // Annualized volatility
  const mean = dailyReturns.reduce((a, b) => a + b, 0) / dailyReturns.length;
  const variance = dailyReturns.reduce((sum, r) => sum + Math.pow(r - mean, 2), 0) / dailyReturns.length;
  const dailyVol = Math.sqrt(variance);
  const annualizedVol = dailyVol * Math.sqrt(365);

  // Max drawdown
  let peak = prices[0];
  let maxDrawdown = 0;
  for (const price of prices) {
    if (price > peak) peak = price;
    const drawdown = (peak - price) / peak;
    if (drawdown > maxDrawdown) maxDrawdown = drawdown;
  }

  return {
    period_days: days,
    annualized_volatility: annualizedVol,
    max_drawdown: maxDrawdown,
    daily_returns: dailyReturns,
  };
}
```

### CoinMarketCap API (Backup)

Used when CoinGecko rate limits are hit or as cross-validation.

```typescript
// Requires API key
const CMC_API_KEY = process.env.CMC_API_KEY;
const CMC_BASE = "https://pro-api.coinmarketcap.com/v1";

async function getCMCPrice(symbol: string): Promise<number> {
  const response = await fetch(
    `${CMC_BASE}/cryptocurrency/quotes/latest?symbol=${symbol}`,
    { headers: { "X-CMC_PRO_API_KEY": CMC_API_KEY! } }
  );
  const data = await response.json();
  return data.data[symbol].quote.USD.price;
}
```

---

## On-Chain RPC Queries

### Supported Chains & RPC Endpoints

| Chain | Default RPC | Fallback RPC | Chain ID |
|-------|-----------|-------------|----------|
| Ethereum | Alchemy / Infura | QuickNode | 1 |
| Arbitrum | Alchemy | QuickNode / Public | 42161 |
| Optimism | Alchemy | QuickNode / Public | 10 |
| Base | Alchemy | QuickNode / Public | 8453 |
| Polygon | Alchemy | QuickNode | 137 |
| Solana | Helius / QuickNode | Public RPC | N/A |

### Common Queries

```typescript
import { ethers } from "ethers";

interface ChainMetrics {
  blockNumber: number;
  gasPrice: bigint;
  baseFee: bigint;
  avgTxCost: number;
  tps: number;
}

async function getChainMetrics(rpcUrl: string): Promise<ChainMetrics> {
  const provider = new ethers.JsonRpcProvider(rpcUrl);

  const [block, feeData] = await Promise.all([
    provider.getBlock("latest"),
    provider.getFeeData(),
  ]);

  // Calculate TPS from last 100 blocks
  const oldBlock = await provider.getBlock(block!.number - 100);
  const timeDiff = block!.timestamp - oldBlock!.timestamp;
  const txCount = block!.transactions.length; // approximate
  const tps = (txCount * 100) / timeDiff;

  // Average tx cost
  const gasPrice = feeData.gasPrice || 0n;
  const avgGasUsed = 65000n; // ERC-20 transfer average
  const avgTxCostWei = gasPrice * avgGasUsed;
  const ethPrice = await getCurrentPrice("ethereum");
  const avgTxCostUsd = Number(ethers.formatEther(avgTxCostWei)) * ethPrice.usd;

  return {
    blockNumber: block!.number,
    gasPrice: gasPrice,
    baseFee: block!.baseFeePerGas || 0n,
    avgTxCost: avgTxCostUsd,
    tps,
  };
}

// Oracle-specific queries
async function getOracleHealth(
  feedAddress: string,
  provider: ethers.Provider,
  maxStaleness: number,
): Promise<{
  healthy: boolean;
  price: number;
  updatedAt: number;
  stalenessSeconds: number;
}> {
  const feed = new ethers.Contract(
    feedAddress,
    ["function latestRoundData() view returns (uint80, int256, uint256, uint256, uint80)"],
    provider,
  );

  const [, answer, , updatedAt, ] = await feed.latestRoundData();
  const now = Math.floor(Date.now() / 1000);
  const staleness = now - Number(updatedAt);

  return {
    healthy: staleness <= maxStaleness && answer > 0n,
    price: Number(answer) / 1e8,
    updatedAt: Number(updatedAt),
    stalenessSeconds: staleness,
  };
}
```

---

## Webhook Configuration

### Supported Webhook Events

| Event | Trigger | Payload |
|-------|---------|---------|
| `chain.tvl.drop` | TVL drops > 10% in 24h | `{chain, old_tvl, new_tvl, pct_change}` |
| `exploit.new` | New exploit detected | `{protocol, chain, amount_usd, type, url}` |
| `oracle.stale` | Oracle feed goes stale | `{feed, chain, staleness_seconds, threshold}` |
| `oracle.deviation` | Price deviation > threshold | `{feed, primary_price, secondary_price, deviation_pct}` |
| `risk.tier_change` | Risk tier changes | `{entity, old_tier, new_tier, score}` |
| `system.pause` | Emergency pause triggered | `{contract, chain, paused_by, reason}` |

### Webhook Configuration Schema

```json
{
  "webhooks": [
    {
      "id": "wh-001",
      "url": "https://your-server.com/hooks/sme-alerts",
      "events": ["chain.tvl.drop", "exploit.new", "oracle.stale"],
      "secret": "${WEBHOOK_SECRET}",
      "retry": {
        "max_attempts": 3,
        "backoff_ms": [1000, 5000, 15000]
      },
      "timeout_ms": 10000,
      "enabled": true
    },
    {
      "id": "wh-002",
      "url": "https://hooks.slack.com/services/xxx/yyy/zzz",
      "events": ["exploit.new", "system.pause", "risk.tier_change"],
      "secret": null,
      "format": "slack",
      "enabled": true
    }
  ]
}
```

### Webhook Delivery

```typescript
async function deliverWebhook(webhook: WebhookConfig, event: WebhookEvent): Promise<void> {
  const payload = {
    id: generateId(),
    timestamp: new Date().toISOString(),
    event: event.type,
    data: event.data,
  };

  const signature = webhook.secret
    ? hmacSha256(webhook.secret, JSON.stringify(payload))
    : null;

  for (let attempt = 0; attempt < webhook.retry.max_attempts; attempt++) {
    try {
      const response = await fetch(webhook.url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(signature && { "X-SME-Signature": signature }),
        },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(webhook.timeout_ms),
      });

      if (response.ok) return;
      if (response.status >= 400 && response.status < 500) return; // Client error, don't retry
    } catch {
      // Network error, retry
    }

    await sleep(webhook.retry.backoff_ms[attempt] || 15000);
  }

  console.error(`Webhook delivery failed after ${webhook.retry.max_attempts} attempts: ${webhook.id}`);
}
```

---

## Polling Intervals & Caching

### Interval Configuration

| Data Source | Polling Interval | Cache TTL | Priority |
|-----------|-----------------|-----------|----------|
| DeFiLlama TVL | 5 minutes | 5 minutes | Medium |
| DeFiLlama Protocol | 10 minutes | 10 minutes | Low |
| L2Beat Summary | 1 hour | 1 hour | Low |
| Rekt.news | 6 hours | 6 hours | Low (alerts: immediate) |
| CoinGecko Price | 1 minute | 1 minute | High |
| CoinGecko Historical | 1 hour | 1 hour | Low |
| On-chain Block Data | 12 seconds (per block) | 12 seconds | Critical |
| Oracle Health | 30 seconds | 30 seconds | Critical |
| Oracle Price | 30 seconds | 30 seconds | Critical |
| Gas Price | 15 seconds | 15 seconds | High |

### Cache Implementation

```typescript
interface CacheEntry<T> {
  data: T;
  timestamp: number;
  ttl: number;
  source: string;
}

class DataCache {
  private store: Map<string, CacheEntry<unknown>> = new Map();

  get<T>(key: string): T | null {
    const entry = this.store.get(key) as CacheEntry<T> | undefined;
    if (!entry) return null;
    if (Date.now() - entry.timestamp > entry.ttl * 1000) {
      this.store.delete(key);
      return null;
    }
    return entry.data;
  }

  set<T>(key: string, data: T, ttl: number, source: string): void {
    this.store.set(key, { data, timestamp: Date.now(), ttl, source });
  }

  isStale(key: string): boolean {
    const entry = this.store.get(key);
    if (!entry) return true;
    return Date.now() - entry.timestamp > entry.ttl * 1000;
  }
}
```

---

## Error Handling & Fallbacks

### Retry Strategy

```typescript
async function fetchWithRetry(
  url: string,
  maxAttempts: number,
  baseDelay: number,
): Promise<Response> {
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      const response = await fetch(url, {
        signal: AbortSignal.timeout(10000),
      });

      if (response.ok) return response;

      // Rate limit: wait and retry
      if (response.status === 429) {
        const retryAfter = parseInt(response.headers.get("Retry-After") || "60");
        await sleep(retryAfter * 1000);
        continue;
      }

      // Server error: retry with backoff
      if (response.status >= 500) {
        await sleep(baseDelay * Math.pow(2, attempt));
        continue;
      }

      // Client error: don't retry
      throw new Error(`HTTP ${response.status}: ${url}`);
    } catch (err) {
      if (attempt === maxAttempts - 1) throw err;
      await sleep(baseDelay * Math.pow(2, attempt));
    }
  }
  throw new Error(`Max retries exceeded: ${url}`);
}
```

### Fallback Chain

```
Primary Source -> Secondary Source -> Cached Value -> Default/Safe Value

Example for price data:
CoinGecko -> CoinMarketCap -> Last cached price (if < 5 min old) -> Pause minting
```

### Health Check Dashboard

| Source | Status | Last Success | Latency | Error Rate |
|--------|--------|-------------|---------|-----------|
| DeFiLlama | OK/WARN/ERR | timestamp | ms | % |
| L2Beat | OK/WARN/ERR | timestamp | ms | % |
| CoinGecko | OK/WARN/ERR | timestamp | ms | % |
| RPC Ethereum | OK/WARN/ERR | timestamp | ms | % |
| RPC Arbitrum | OK/WARN/ERR | timestamp | ms | % |
| Oracle Feed X | OK/WARN/ERR | timestamp | ms | % |
