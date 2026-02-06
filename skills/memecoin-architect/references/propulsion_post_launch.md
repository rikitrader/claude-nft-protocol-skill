# Module 11: "Propulsion" Post-Launch Growth Engine

## Purpose

Automate the post-launch growth pipeline: DEX tracker visibility, influencer outreach, listing applications, and community scaling. This module converts a "launched token" into a "discoverable project."

## Triggers

Activate Propulsion when:
- Token is deployed and trading on DEX (Phase 3 complete)
- User says "post-launch", "growth", "propulsion", "get listed"
- Execution mode includes `--with-growth` flag

## Growth Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│              POST-LAUNCH GROWTH PIPELINE                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  T+0h     T+1h     T+24h    T+48h    T+7d    T+30d        │
│  ├────────┼────────┼────────┼────────┼───────┼────────┤    │
│  │ DEX    │ Social │ KOL    │ CMC/CG │ CEX   │ Review │    │
│  │Tracker │ Push   │Outreach│ Apply  │ Watch │ & Grow │    │
│  │ Setup  │        │        │        │       │        │    │
│  └────────┴────────┴────────┴────────┴───────┴────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Output Artifacts

```
/repo
  /growth
    /dex_trackers
      /dexscreener_setup.md      # DEXScreener paid profile guide
      /dextools_setup.md         # DEXTools listing + update guide
      /birdeye_setup.md          # Birdeye token profile setup
      /geckoterminal_setup.md    # GeckoTerminal setup guide
    /listings
      /coingecko_application.md  # CoinGecko listing checklist
      /cmc_application.md        # CoinMarketCap listing checklist
      /jupiter_strict.md         # Jupiter strict list application
    /outreach
      /kol_research_brief.md     # KOL identification & outreach
      /partnership_brief.md      # Partnership pitch template
      /press_kit.md              # Press/media contact template
    /community
      /growth_playbook.md        # 30-day community growth plan
      /engagement_metrics.md     # KPIs and tracking guide
      /raid_guidelines.md        # Ethical engagement rules
```

## DEX Tracker Setup

### DEXScreener

```
DEXSCREENER PROFILE SETUP:
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│  Step 1: Verify token appears on DEXScreener                │
│          - Search: dexscreener.com/solana/{MINT_ADDRESS}    │
│          - Usually auto-indexed within 5-30 minutes         │
│                                                              │
│  Step 2: Claim token profile                                 │
│          - Visit: dexscreener.com/token-profile             │
│          - Connect deployer wallet for verification          │
│          - Cost: ~$300 for Enhanced Profile                  │
│                                                              │
│  Step 3: Upload profile data                                 │
│          - Logo (400x400 PNG, transparent background)       │
│          - Banner (1200x400 PNG)                             │
│          - Description (from one_pager.md)                   │
│          - Social links (X, Telegram, Discord, Website)     │
│          - Website URL                                       │
│                                                              │
│  Step 4: Enable paid features (optional)                     │
│          - Boosted badge ($299/month)                        │
│          - Top banner ads ($599-2999/day)                    │
│          - Community notes enabled                           │
│                                                              │
│  TIMELINE: Profile live within 24 hours of claim             │
└─────────────────────────────────────────────────────────────┘
```

### DEXTools

```
DEXTOOLS LISTING:
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│  Step 1: Token auto-indexed (usually within 1 hour)         │
│                                                              │
│  Step 2: Update token info via DEXT Force                    │
│          - Visit: dextools.io/app/solana/token-update       │
│          - Submit: logo, description, social links           │
│          - Verification: deployer wallet signature           │
│                                                              │
│  Step 3: Request audit score                                 │
│          - DEXT Score is auto-calculated                     │
│          - Higher score = more visibility                    │
│          - Key factors:                                      │
│            ✅ Mint authority revoked                          │
│            ✅ LP locked/burned                                │
│            ✅ No freeze authority                             │
│            ✅ Top holders < 5% each                           │
│            ✅ Contract verified                               │
│                                                              │
│  TARGET: DEXT Score > 80 (all Vigilante checks pass)        │
└─────────────────────────────────────────────────────────────┘
```

## Listing Applications

### CoinGecko Application

```
COINGECKO REQUIREMENTS:
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│  MANDATORY (all must be true):                               │
│  ☐ Token is trading on a supported DEX                      │
│  ☐ Working website with project description                 │
│  ☐ Logo (PNG, 250x250 minimum)                              │
│  ☐ Active social media (X/Twitter required)                 │
│  ☐ Circulating supply data available                        │
│  ☐ Contact email                                            │
│                                                              │
│  STRONGLY RECOMMENDED:                                       │
│  ☐ >$50K daily trading volume (7-day average)               │
│  ☐ >500 unique holders                                      │
│  ☐ Telegram community >1000 members                         │
│  ☐ CoinGecko Candy program participation                    │
│  ☐ Smart contract verified on explorer                      │
│                                                              │
│  APPLICATION:                                                │
│  URL: coingecko.com/en/coins/new                            │
│  Review time: 5-15 business days                             │
│  Cost: Free                                                  │
│                                                              │
│  FIELDS TO PREPARE:                                          │
│  - Project name: {TOKEN_NAME}                                │
│  - Ticker: {TICKER}                                          │
│  - Chain: Solana                                             │
│  - Contract address: {MINT_ADDRESS}                          │
│  - Description: (from one_pager.md)                          │
│  - Category: Meme                                            │
│  - Launch date: {LAUNCH_DATE}                                │
│  - Total supply: {SUPPLY}                                    │
│  - Max supply: {SUPPLY} (fixed)                              │
│  - Circulating supply API endpoint (optional)                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### CoinMarketCap Application

```
CMC REQUIREMENTS:
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│  MANDATORY:                                                  │
│  ☐ Listed on at least 1 tracked exchange/DEX                │
│  ☐ Working block explorer link                              │
│  ☐ Website with detailed project information                │
│  ☐ Working smart contract with verified source              │
│  ☐ Self-reported circulating supply                         │
│                                                              │
│  APPLICATION:                                                │
│  URL: support.coinmarketcap.com (via support ticket)        │
│  Form: coinmarketcap.com/request                            │
│  Review time: 15-30+ business days                           │
│  Cost: Free (expedited review: paid, varies)                │
│                                                              │
│  BEST PRACTICES:                                             │
│  - Apply AFTER CoinGecko listing (increases credibility)    │
│  - Include link to CoinGecko page in application            │
│  - Provide circulating supply API endpoint                  │
│  - Have >$100K daily volume before applying                 │
│  - Submit complete information first time (resubmissions    │
│    go to back of queue)                                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Jupiter Strict List

```
JUPITER STRICT LIST:
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│  Jupiter has two token lists:                                │
│  - "All" list: Auto-indexed (your token is already here)    │
│  - "Strict" list: Curated, verified tokens only             │
│                                                              │
│  STRICT LIST REQUIREMENTS:                                   │
│  ☐ >$250K daily volume (sustained)                          │
│  ☐ Listed on CoinGecko or CMC                               │
│  ☐ >1000 unique holders                                     │
│  ☐ Active community and social presence                     │
│  ☐ No rug-pull indicators                                   │
│  ☐ Mint authority revoked                                   │
│  ☐ Freeze authority revoked                                 │
│                                                              │
│  APPLICATION:                                                │
│  GitHub PR: github.com/jup-ag/token-list                    │
│  Add token metadata to verified-tokens directory             │
│  Community review process                                    │
│                                                              │
│  BENEFIT: "Strict" badge on Jupiter = significantly more    │
│  organic volume and trust                                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## KOL Outreach

### Research Brief Generator

```
KOL RESEARCH FRAMEWORK:
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│  Step 1: IDENTIFY (10-20 candidates)                        │
│                                                              │
│  Search queries:                                             │
│  - "{NARRATIVE_THEME} crypto twitter KOL"                   │
│  - "solana memecoin influencer"                              │
│  - "{COMPETITOR} promoted by"                                │
│                                                              │
│  Filters:                                                    │
│  - Followers: 10K-500K (sweet spot for engagement)          │
│  - Engagement rate: >2%                                      │
│  - Posts about Solana/memecoins in last 7 days              │
│  - NOT in "paid shill" lists / known scammers               │
│                                                              │
│  Step 2: SCORE (per candidate)                              │
│                                                              │
│  | Criterion         | Weight | Score (0-10) |              │
│  |-------------------|--------|-------------|               │
│  | Audience relevance| 30%    |             |               │
│  | Engagement rate   | 25%    |             |               │
│  | Content quality   | 20%    |             |               │
│  | Past promotions   | 15%    |             |               │
│  | Price estimate    | 10%    |             |               │
│                                                              │
│  Step 3: OUTREACH TEMPLATE                                  │
│                                                              │
│  Subject: "{TOKEN_NAME} — Collab Opportunity"               │
│  Body:                                                       │
│  - Who we are (1 sentence)                                  │
│  - Why them specifically (personalized)                     │
│  - What we're offering (tokens, payment, or both)           │
│  - Media kit attached (from Narrative Forge)                │
│  - No pressure / "Let us know if interested"                │
│                                                              │
│  Step 4: TRACK                                              │
│  Spreadsheet with: Name, Contact, Status, Rate, Notes       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Outreach Do's and Don'ts

| Do | Don't |
|----|-------|
| Personalize every message | Mass DM the same template |
| Offer fair compensation | Promise unrealistic returns |
| Provide media kit + facts | Ask them to "shill" |
| Respect their audience | Pressure for positive coverage |
| Disclose it's a promotion | Hide the paid nature |
| Target niche-relevant KOLs | Spam unrelated influencers |

## Community Growth Playbook

### 30-Day Plan

```
┌─────────────────────────────────────────────────────────────┐
│              30-DAY COMMUNITY GROWTH PLAN                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  WEEK 1: FOUNDATION (Days 1-7)                               │
│  ├─ Launch Telegram + Discord                                │
│  ├─ Post launch thread (from Narrative Forge)               │
│  ├─ DEXScreener profile claimed                             │
│  ├─ Daily engagement in Solana alpha groups                 │
│  ├─ Target: 500 Telegram members                            │
│  └─ KPI: 200 unique holders                                 │
│                                                              │
│  WEEK 2: MOMENTUM (Days 8-14)                                │
│  ├─ First KOL partnership live                              │
│  ├─ Meme contest in community (prizes in tokens)            │
│  ├─ CoinGecko application submitted                         │
│  ├─ First milestone thread (burn stats, holder growth)      │
│  ├─ Target: 2000 Telegram members                           │
│  └─ KPI: 1000 unique holders, $50K daily volume             │
│                                                              │
│  WEEK 3: EXPANSION (Days 15-21)                              │
│  ├─ 2-3 more KOL partnerships                               │
│  ├─ CMC application submitted                                │
│  ├─ Collaboration with another project (cross-promo)        │
│  ├─ Governance proposal #1 (community decides something)    │
│  ├─ Target: 5000 Telegram members                           │
│  └─ KPI: 3000 holders, $100K daily volume                   │
│                                                              │
│  WEEK 4: CONSOLIDATION (Days 22-30)                          │
│  ├─ Jupiter strict list application                          │
│  ├─ Whitepaper v1 published                                 │
│  ├─ Dashboard (Aura UI) live and promoted                   │
│  ├─ Review all KPIs, plan Month 2                           │
│  ├─ Target: 10000 Telegram members                          │
│  └─ KPI: 5000 holders, $250K daily volume                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Engagement KPIs

| Metric | Week 1 | Week 2 | Week 3 | Week 4 |
|--------|--------|--------|--------|--------|
| Unique holders | 200 | 1,000 | 3,000 | 5,000 |
| Telegram members | 500 | 2,000 | 5,000 | 10,000 |
| Daily volume | $10K | $50K | $100K | $250K |
| X/Twitter followers | 500 | 2,000 | 5,000 | 10,000 |
| CoinGecko listed | No | Applied | Pending | Yes |
| CMC listed | No | No | Applied | Pending |

### Ethical Guidelines

```
COMMUNITY ENGAGEMENT RULES:
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│  ✅ ALLOWED:                                                 │
│  - Sharing project updates in relevant groups               │
│  - Responding to questions about the token                  │
│  - Hosting AMAs and community events                        │
│  - Running meme contests with token prizes                  │
│  - Collaborating with other legitimate projects             │
│                                                              │
│  ❌ PROHIBITED:                                              │
│  - Brigading other project communities                      │
│  - Fake accounts or bot engagement                          │
│  - Price manipulation or coordinated pumping                │
│  - Spreading FUD about competitors                          │
│  - Promising returns or guaranteed profits                  │
│  - Undisclosed paid promotions                              │
│                                                              │
│  DISCLOSURE: All paid promotions MUST be disclosed.          │
│  Failure to disclose violates FTC guidelines and            │
│  damages project credibility.                                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Downstream Integration

| Consumer | Fields Used |
|----------|-------------|
| Module 8 (Aura UI) | Dashboard link for DEX tracker profiles |
| Module 9 (Narrative Forge) | Media kit for KOL outreach packages |
| Module 10 (Vigilante) | Authority verification for DEXT score |
| Phase 3 (Post-Deploy) | Full growth pipeline triggered after deploy |
| MEMECOIN_BRIEF.md | R2 competitor data for KOL targeting |
