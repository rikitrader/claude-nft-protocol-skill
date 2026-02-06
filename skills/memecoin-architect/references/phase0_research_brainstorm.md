# Phase 0: Research & Brainstorm Engine

## Purpose

Phase 0 is the **mandatory entry point** for any new memecoin project. Before designing tokenomics, writing contracts, or generating a repo, research the market. This phase produces a `MEMECOIN_BRIEF.md` that anchors all downstream design, contract, and deployment decisions.

**Do not skip this phase unless the user provides a pre-existing brief or explicitly requests locked defaults.**

## Triggers

Activate Phase 0 when the user says:
- "research", "brainstorm", "phase 0", "market analysis"
- "I want to launch a memecoin" (implies research needed first)
- "new memecoin project" or "memecoin idea"
- Any new project request without an existing `MEMECOIN_BRIEF.md`

## Research Modules

Phase 0 consists of 5 research modules executed in order. Each module produces structured output that feeds into the `MEMECOIN_BRIEF.md`.

---

### Module R1: Market Landscape Analysis

**Method:** Web search for real-time data.

**Research targets:**
- Top 20 memecoins by market cap (current)
- 7-day volume leaders on Solana, Base, and Ethereum
- Recent launches (<30 days) with >$1M market cap
- Trending narratives (AI, animals, political, cultural, absurdist)
- DEX volume distribution by chain (Raydium vs Uniswap vs Aerodrome)

**Web searches to execute:**
1. `"top memecoins by market cap [current month year]"`
2. `"solana memecoin launches this week"`
3. `"base chain memecoin volume [current month year]"`
4. `"memecoin trends [current month year]"`

**Output fields:**

| Field | Type | Description |
|-------|------|-------------|
| `date` | string | Snapshot date |
| `total_memecoin_mcap` | string | Total memecoin market cap |
| `dominant_narrative` | string | Currently winning theme |
| `market_sentiment` | enum | bullish / neutral / bearish |
| `top_performers` | table | Name, chain, mcap, 7d volume, launch date |
| `trending_narratives` | table | Name, momentum (0-10), saturation (0-10), opportunity |

---

### Module R2: Competitor Deep-Dive

**Method:** Analyze 3-5 direct competitors in the user's chosen or emerging narrative.

**Research per competitor:**

| Attribute | How to Find |
|-----------|-------------|
| Token supply model | On-chain explorer (Solscan, Basescan) |
| Distribution breakdown | Token holder analysis |
| LP strategy | Pool depth, lock status, duration |
| Holder concentration | Top 10 wallets % |
| Social metrics | Twitter followers, Telegram members, Discord |
| Unique mechanics | Burns, staking, NFT integration, games |
| Team status | Doxxed? Audited? |

**Web searches to execute:**
5. `"[narrative] memecoin competitors [current year]"`

**Output fields:**

For each competitor:
| Field | Type |
|-------|------|
| `name` | string |
| `chain` | string |
| `supply` | number |
| `lp_pct` | percentage |
| `team_pct` | percentage |
| `burn_mechanics` | string |
| `holder_count` | number |
| `social_score` | 0-10 |
| `strengths` | list |
| `weaknesses` | list |
| `lessons` | list |

Plus a **Competitive Gap Analysis** showing where the new token can differentiate.

---

### Module R3: Chain Selection (Weighted Scoring)

**Method:** Evaluate 3+ chains using a weighted scoring matrix.

**Scoring Criteria:**

| Criterion | Weight | What to Measure |
|-----------|--------|-----------------|
| Liquidity depth | 25% | DEX TVL, daily volume, USDC pair availability |
| Fee economics | 20% | Cost per tx, impact on micro-trades |
| Degen community | 20% | Active memecoin trader base, social activity |
| DEX infrastructure | 15% | Aggregators (Jupiter/1inch), AMMs, launch tools |
| Bridge options | 10% | Cross-chain expansion potential |
| Regulatory risk | 10% | Jurisdiction clarity, enforcement history |

Each criterion scored **0-10** per chain. Weighted total determines selection.

**Elimination Rules (auto-fail):**

| Code | Rule | Rationale |
|------|------|-----------|
| E-01 | Chain daily DEX volume < $10M | Insufficient liquidity |
| E-02 | No established AMM with USDC pair support | Cannot create primary pair |
| E-03 | Known regulatory ban in target markets | Legal risk |
| E-04 | No Jupiter/1inch-equivalent aggregator | No routing = no discovery |
| E-05 | Chain TPS < 100 in practice | User experience degradation |
| E-06 | No Anchor/Foundry equivalent tooling | Cannot deploy contracts |

**Output fields:**

| Field | Type |
|-------|------|
| `chain_scores` | table (chain, criterion scores, weighted total, eliminated?, reason) |
| `selected_chain` | string + rationale |
| `mirror_chains` | list with priority (high/medium/low) |

---

### Module R4: Naming & Branding Brainstorm

**Method:** Generate 5-10 candidate names, score each.

**Evaluation Criteria:**

| Criterion | Weight | What to Check |
|-----------|--------|---------------|
| Memetic potential | 30% | Spreadability, remix-ability, meme template fit |
| Ticker availability | 20% | Not taken on DEXs, CoinGecko, CoinMarketCap |
| Social handle availability | 20% | Twitter/X, Telegram group name |
| Domain availability | 15% | .com, .io, .xyz |
| Cultural sensitivity | 10% | Offensive in other languages? Trademark conflicts? |
| Visual/logo potential | 5% | Can it become a recognizable brand? |

**Web searches to execute:**
6. `"[candidate name] crypto token"` (name conflict check)
7. `"[candidate ticker] token"` (ticker conflict check)

**Output fields:**

For each candidate:
| Field | Type |
|-------|------|
| `name` | string |
| `ticker` | string (3-5 chars) |
| `memetic_score` | 0-10 |
| `ticker_available` | boolean |
| `domain_available` | list (.com, .io, .xyz) |
| `social_handles` | object (twitter: bool, telegram: bool) |
| `cultural_risks` | list |
| `logo_concept` | string (1-2 sentence visual direction) |

Plus a **Recommended** pick with rationale.

---

### Module R5: Utility & Narrative Design

**Method:** Define what makes this token more than "mint & pray".

**Framework (answer each):**

| # | Question | Purpose |
|---|----------|---------|
| 1 | **Core narrative** | One sentence that explains the meme |
| 2 | **Launch hook** | What creates the initial viral moment? |
| 3 | **Retention mechanics** | What keeps holders after launch? |
| 4 | **Expansion vector** | How does it grow beyond initial community? |
| 5 | **Revenue model** | How does the treasury get funded? |
| 6 | **Exit-to-utility path** | Meme to real product (if applicable) |

**Output fields:**

| Field | Type |
|-------|------|
| `narrative.one_liner` | string |
| `narrative.expanded_pitch` | string (2-3 paragraphs) |
| `launch_strategy.hook` | string |
| `launch_strategy.target_communities` | list |
| `launch_strategy.initial_catalyst` | string |
| `launch_strategy.timeline_days` | number |
| `retention.mechanics` | list |
| `retention.staking` | boolean |
| `retention.nft_integration` | boolean |
| `retention.gamification` | list |
| `revenue_sources` | table (source, est. annual range, phase) |
| `utility_roadmap` | table (phase, timeline, milestone) |

---

## Go/No-Go Gate

After completing all 5 modules, evaluate the project viability.

### GO Criteria (ALL must be true)

| # | Criterion | Threshold |
|---|-----------|-----------|
| G-1 | Selected chain weighted score | >= 6.0 / 10 |
| G-2 | At least 1 candidate name memetic score | >= 7 / 10 |
| G-3 | Narrative one-liner is clear and differentiated | Subjective pass |
| G-4 | At least 2 revenue sources identified | Count >= 2 |
| G-5 | No unresolvable regulatory blockers | Pass |

### CAUTION Criteria (proceed with documented risk)

- Chain score 5.0-5.9
- All candidate names memetic_score < 7 but >= 5
- Narrative similar to 3+ existing tokens
- Single revenue source

### NO-GO Criteria (ANY triggers NO-GO)

| # | Criterion | Trigger |
|---|-----------|---------|
| N-1 | Chain score | < 5.0 |
| N-2 | No viable name/ticker combination | All eliminated |
| N-3 | Regulatory hard-block in primary market | Confirmed |
| N-4 | Zero differentiation from top 5 competitors | Indistinguishable |

**Recommendation output:** `GO` / `CAUTION` / `NO-GO` with rationale.

---

## MEMECOIN_BRIEF.md Output Schema

When Phase 0 completes, generate this document:

```markdown
# MEMECOIN BRIEF: [TOKEN NAME]

## Meta
- **Generated:** [date]
- **Phase 0 Status:** [GO / CAUTION / NO-GO]
- **Confidence:** [0-100]%
- **Data Sources:** [count] web searches cited below

## 1. Market Snapshot
[R1 output: landscape table, trending narratives, sentiment]

## 2. Competitor Analysis
[R2 output: 3-5 competitor profiles, gap analysis diagram]

## 3. Chain Selection
[R3 output: scoring matrix, selected chain, mirror chains]

## 4. Name & Branding
[R4 output: candidate table, recommended pick, logo concept]

## 5. Narrative & Utility
[R5 output: one-liner, launch strategy, retention, revenue, roadmap]

## 6. Go/No-Go Assessment
[Scorecard table with PASS/FAIL per criterion, final recommendation]

## 7. Design Parameters
These values feed downstream phases and override locked defaults
when provided:

| Parameter | Brief Value | Default | Override? |
|-----------|-------------|---------|-----------|
| Token Name | [from R4] | (none) | YES |
| Ticker | [from R4] | (none) | YES |
| Chain | [from R3] | Solana | [YES/NO] |
| Total Supply | [from analysis] | 1,000,000,000 | [YES/NO] |
| LP % | [from analysis] | 70% | [YES/NO] |
| Initial USDC | [from analysis] | $100,000 | [YES/NO] |
| Burn Mechanics | [from R2+R5] | 1% per trade | [YES/NO] |
| Mirror Chains | [from R3] | ETH + Base | [YES/NO] |

## Sources
- [URL 1] - [description]
- [URL 2] - [description]
- ...
```

---

## Downstream Consumption

How each downstream phase uses the brief:

| Downstream Phase | Fields Consumed |
|------------------|-----------------|
| Module 1: Token Layer | selected_chain, ticker, supply model from competitors |
| Module 2: Burn Mechanics | competitors[].burn_mechanics, retention.mechanics |
| Module 3: Treasury | revenue_sources, utility_roadmap |
| Module 4: Liquidity | chain_scores (liquidity_depth), competitors[].lp_pct |
| Module 5: Governance | utility_roadmap phases |
| Module 6: Emergency | chain-specific risk profile |
| Module 7: Stability | revenue_sources, competitor analysis |
| Execution Master Prompt | ALL fields (overrides locked defaults via Section 7) |
| Tokenomics Template | name, ticker, distribution derived from competitors |
| Cross-Chain Mirror | mirror_chains selection |

---

## Manual Research Fallback

If web search is unavailable (offline mode, restricted environment), use this questionnaire instead. The user provides answers manually; the output format is identical.

### Manual Research Questionnaire

```
1. MARKET: What memecoin narratives are currently trending?
   (AI, animals, political, cultural, other: ___)

2. COMPETITORS: Name 3-5 memecoins in your target narrative.
   For each: name, chain, approximate market cap, unique mechanic.

3. CHAIN: Which chain do you prefer? Why?
   Rate 0-10: liquidity, fees, community, DEX tools, bridges, regulatory.

4. NAME: List 3-5 candidate names and tickers.
   For each: memetic appeal (0-10), any known conflicts?

5. NARRATIVE: In one sentence, what is the meme?

6. UTILITY: What keeps holders after launch day?
   (burns, staking, NFTs, games, governance, other: ___)

7. REVENUE: How does the treasury earn? List sources.

8. TIMELINE: When do you want to launch? (days from now)
```

Responses are structured into the same `MEMECOIN_BRIEF.md` format.

---

## Staleness Warning

The brief includes a generation date. Downstream phases should warn if the brief is older than 7 days:

> "Brief generated [X] days ago. Market conditions may have changed. Consider re-running Phase 0 for fresh data."
