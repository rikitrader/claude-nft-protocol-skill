---
name: memecoin-architect
description: Production-grade memecoin system architect for Solana, Base, and Ethereum. This skill should be used when designing tokenomics, writing Anchor smart contracts, creating Pump-style launch mechanics, building liquidity strategies, implementing burn mechanics, treasury systems, governance, dashboards, CI/CD pipelines, cross-chain mirror deployments, frontend dashboards, marketing content, MEV/sniper protection, or post-launch growth. Triggers on memecoin design, token launch, Solana token, Anchor contracts, DEX liquidity, anti-rug mechanics, viral token architecture, market research, brainstorm, competitor analysis, chain selection, dashboard UI, narrative forge, content strategy, anti-bot, fair launch, DEXScreener, CoinGecko listing, or KOL outreach.
---

# Memecoin Architect

Production-grade memecoin system design for Solana (primary), Base, and Ethereum.

This is NOT a "mint & pray" system. This is **follow-the-money architecture**.

## Workflow

```
Phase 0: Research & Brainstorm    ← ENTRY POINT (start here)
    |
    v  produces MEMECOIN_BRIEF.md
Phase 1: Design (Modules 1-7)    ← Tokenomics, burns, treasury, governance
    |
    v
Phase 2: Execute                  ← Full repo generation ("execution mode")
    |
    v
Phase 3: Pre-Deploy -> Deploy -> Post-Deploy
```

### Phase 0: Research & Brainstorm

**THE FIRST STEP.** Before designing tokenomics or writing contracts, research the market.

Reference `references/phase0_research_brainstorm.md` for the full research engine.

**Trigger:** "research", "brainstorm", "phase 0", "market analysis", or starting any new memecoin project.

**Produces:** `MEMECOIN_BRIEF.md` — a structured research document that feeds all downstream phases.

**Modules:**
- R1: Market Landscape Analysis (web search for real-time data)
- R2: Competitor Deep-Dive (3-5 competitors analyzed)
- R3: Chain Selection (weighted scoring matrix with elimination rules)
- R4: Naming & Branding Brainstorm (5-10 candidates scored)
- R5: Utility & Narrative Design (launch hook, retention, revenue model)

**Go/No-Go Gate:** Phase 0 produces a GO / CAUTION / NO-GO recommendation before proceeding to design. A NO-GO halts the project with clear reasoning.

**Skip:** Phase 0 can be skipped only if the user provides a pre-existing brief or explicitly says "skip research" / "use defaults".

## Core Principles

- No infinite mint
- Burns tied to activity (deterministic)
- Treasury governed, not rug-able
- Emergency controls (limited + auditable)
- On-chain metrics visible

## Chain Selection (2026 Reality)

> **Note:** When a `MEMECOIN_BRIEF.md` exists from Phase 0, the chain selection
> from R3 (weighted scoring) overrides this default matrix.

```
┌─────────────────────────────────────────────────────────────┐
│                    CHAIN DECISION MATRIX                     │
├──────────┬─────────────────────────────────────────────────┤
│ SOLANA   │ Primary launch chain (90% of winners)           │
│          │ Ultra-low fees, massive degen liquidity         │
│          │ Fast finality, Jupiter/Raydium infra            │
├──────────┼─────────────────────────────────────────────────┤
│ BASE     │ Institutional + normie bridge                   │
│          │ Coinbase backing, ETH security                  │
│          │ Serious meme → real product transitions         │
├──────────┼─────────────────────────────────────────────────┤
│ ETHEREUM │ Post-meme evolution only                        │
│          │ Liquidity depth, but fees kill grassroots       │
├──────────┼─────────────────────────────────────────────────┤
│ BSC      │ ❌ NOT RECOMMENDED - reputation issues          │
│ New Chains│ ❌ NOT RECOMMENDED - no liquidity gravity      │
└──────────┴─────────────────────────────────────────────────┘
```

## System Architecture

```
┌──────────────────────────────────────────┐
│        MEMECOIN PROTOCOL CONTROL          │
├───────────────┬──────────────────────────┤
│ Token Mint    │ Fixed / Immutable         │
│ Burn Engine   │ Volume + Activity Based   │
│ Treasury      │ Multi-sig / DAO           │
│ Launch Engine │ Pump-style / Anti-rug     │
│ Dashboard     │ Real-time metrics         │
│ Stability     │ Buyback + Burn (Soft)     │
│ Emergency     │ Pause / Lock / Alert      │
│ Aura UI       │ Glassmorphic Dashboard    │
│ Narrative     │ Content + Media Kit       │
│ Vigilante     │ MEV / Sniper Protection   │
│ Propulsion    │ Post-Launch Growth        │
└──────────────────────────────────────────┘
```

## Module 1: Token Layer

**Fixed Supply Architecture:**
- Total Supply: FIXED (e.g., 1,000,000,000)
- Mint: ONE-TIME ONLY (constructor)
- Decimals: 6-9 (Solana standard)
- No owner mint privileges post-deploy

**Distribution Model (Anti-Rug):**

| Allocation | % | Rules |
|------------|---|-------|
| Liquidity Pool | 70% | LP tokens locked or burned |
| Community/Airdrop | 15% | Fair distribution |
| Treasury DAO | 10% | Multi-sig + DAO gated |
| Team (VESTED) | 5% | Time-lock vesting |

## Module 2: Burn Mechanics

Burns must be **mechanical, not emotional**.

**Burn Triggers:**
- % burn on every trade
- Burn triggered by volume thresholds
- Burn tied to social actions (NFT mint, vote, game)
- Treasury buyback → burn

**Rules:**
- ❌ No manual burn buttons
- ✅ Deterministic rules only

## Module 3: Treasury System

**Revenue Sources:** NFT mints, Merch, Partner fees, Game fees

**Treasury Controls:** Multi-sig required, DAO proposals, Spend caps enforced

**Treasury Can:** Buy & burn, Fund marketing, Seed products, Provide LP support

### Treasury Policy (MUST IMPLEMENT)

```
┌─────────────────────────────────────────────────────────────┐
│              TREASURY POLICY — MANDATORY                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  DEFAULT: NO NEW MINTS EVER                                  │
│  Total supply is FIXED at initialization.                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Reserve Management:**

Treasury may hold an uncirculated reserve that is ALREADY minted.

Reserve release requires:
- ✅ Governance proposal + threshold approvals
- ✅ Timelock delay
- ✅ Rate limit (max % of supply per week)
- ✅ On-chain event logs

**Market Support (PREFERRED METHOD):**

```
BUYBACK + BURN FLOW:
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Treasury    │───→│ Buy on DEX  │───→│ Burn tokens │
│ triggers    │    │ (Raydium/   │    │ permanently │
│ buyback     │    │  Jupiter)   │    │             │
└─────────────┘    └─────────────┘    └─────────────┘
```

Triggers are deterministic:
- Volume thresholds
- Volatility bands
- Revenue milestones

**Optional: Capped Supply Expansion (only if explicitly enabled)**

| Requirement | Implementation |
|-------------|----------------|
| Hard max supply | Immutable constant |
| Mint budget | Tracked on-chain |
| Rate-limited mints | Governance + timelock only |

⚠️ **Supply expansion is OFF by default. Must be explicitly enabled at initialization.**

## Module 4: Liquidity Engine

**DEX Stack:** Raydium + Jupiter

**LP Protection:**
- LP Lock: 6-12 months minimum
- Auto LP burn on milestones
- No withdraw authority

## Module 5: Governance Roadmap

| Phase | Control Model |
|-------|---------------|
| Phase 1 | Core team + multisig |
| Phase 2 | Snapshot voting |
| Phase 3 | On-chain DAO |

## Module 6: Emergency Controls

**Available:** Trading pause, LP freeze, Treasury lock, Oracle-based anomaly detection

**Used ONLY For:** Exploits, DEX attacks, Chain instability

**Constraints:** Time-limited, Logged on-chain, Cannot mint or rug

## Module 7: Stablecoin-Adjacent Mechanics (Optional)

Meme token with stabilization mechanics WITHOUT becoming a regulated stablecoin.

- Treasury-backed soft floor
- Buyback + burn mechanics
- No explicit peg claim

**Safety Rules (Critical):**
- ❌ No fixed $ peg
- ❌ No guaranteed redemption
- ❌ No yield promises
- ✅ Disclosures baked into metadata

## Module 8: "Aura" Dashboard Engine

Multi-view Next.js 15 App Router application with three views: Landing Page, Holder Dashboard, and Admin Dashboard. All views use the glassmorphic Aura design system and read live on-chain data from the 5 Anchor programs.

Reference `references/aura_ui_engine.md` for design specs.

**Architecture:**
- Route group `(landing)` — Crypto-native dark marketing page (public, no wallet required)
- Route group `(dashboard)` — Holder dashboard with bento grid (wallet optional for read-only)
- Route group `(dashboard)/admin` — Wallet-gated admin area (treasury signers + emergency guardians only)

**Data Layer (6 hooks):**
- `useTokenMetrics` — MintState + BurnState PDAs (supply, burned, burn rate)
- `useTreasuryData` — TreasuryState PDA (balance, signers, proposals)
- `useGovernanceData` — GovernanceState PDA (owners, threshold, config proposals)
- `useEmergencyStatus` — EmergencyState PDA (pause state, guardian votes)
- `usePriceData` — Jupiter Price API v2 (price, 24h change, volume)
- `useRoleGuard` — Client-side wallet check against signers[] and guardians[]

**Admin Features:**
- Treasury: View balance, proposals, create new transfer proposals
- Governance: View owners, threshold, config proposals
- Emergency: Vote pause/resume with confirmation workflow
- Burns: View burn metrics, execute treasury buyback + burn

**Components:** BurnMeter, TreasuryCard, PriceChart, HolderMap, LPStatus, SupplyTicker, ProposalList, EmergencyControls, BuybackBurnForm, RoleGuard, TransactionButton, AnimatedNumber, Sparkline, StatusBadge

**Stack:** Next.js 15 + Tailwind CSS 4 + TanStack Query + Recharts + Framer Motion + @solana/wallet-adapter

**Trigger:** Included automatically in execution mode repo generation.

## Module 9: "Narrative Forge" Content Engine

AI-powered marketing asset generator.

Reference `references/narrative_forge.md` for templates and prompts.

**Outputs:**
- 5-part X/Twitter launch thread (AIDA framework)
- 10 DALL-E/Midjourney meme prompts
- Telegram/Discord announcement templates
- Whitepaper PDF structure
- Brand guide + media kit

**Trigger:** "generate marketing", "narrative forge", or after Phase 0 brief is complete.

## Module 10: "Vigilante" Security Suite

MEV and sniper protection for fair launches.

Reference `references/vigilante_security.md` for implementation details.

**Protections:**
- JITO-bundled LP addition (private mempool)
- Anti-bot time-weighted swap caps (first 30 min)
- Metadata immutability scripts (one-click lock)
- Authority verification (post-deploy checker)
- Sandwich attack mitigation guidance

**Trigger:** Included in execution mode. Security scripts auto-generated.

## Module 11: "Propulsion" Post-Launch Growth

Automated growth pipeline for token visibility and community scaling.

Reference `references/propulsion_post_launch.md` for full playbook.

**Pipeline:**
- DEXScreener / DEXTools profile setup
- CoinGecko + CoinMarketCap listing applications
- Jupiter strict list application
- KOL research and outreach briefs
- 30-day community growth playbook

**Trigger:** "post-launch", "growth", "propulsion", "get listed", or after Phase 3 deploy.

## Resources

### Anchor Contracts

Reference `scripts/anchor_contracts/` for production-ready Solana programs:
- `token_mint.rs` - Fixed supply, one-time mint
- `burn_controller.rs` - Deterministic burn logic
- `treasury_vault.rs` - PDA-controlled treasury
- `governance_multisig.rs` - Multi-sig operations
- `emergency_pause.rs` - Time-limited pause

### DEX Scripts

Reference `scripts/dex/` for liquidity operations:
- `raydium_lp.sh` - Initial pool creation
- `jupiter_integration.md` - Aggregator integration guide

### Security Scripts

Reference `scripts/security/` for post-deploy hardening:
- `jito_lp_add.ts` - JITO-bundled LP addition (private mempool)
- `lock_metadata.ts` - Metaplex + Token-2022 metadata immutability
- `verify_authorities.ts` - 6-check post-deploy authority verification (CI exit codes)

### Templates

Reference `templates/aura/` for Next.js dashboard skeleton:
- `app/layout.tsx` - Root layout + wallet providers
- `app/page.tsx` - Bento grid dashboard
- `app/globals.css` - Aura design tokens
- `components/wallet/WalletProvider.tsx` - Solana wallet adapter
- `lib/anchor-client.ts` - Anchor IDL + program connection
- `lib/constants.ts` - Program IDs, RPC endpoints

Reference `templates/narrative_forge/` for marketing templates:
- `threads/launch_thread.md` - 5-part AIDA launch thread
- `visuals/brand_guide.md` - Colors, fonts, logo, AI prompts
- `media_kit/one_pager.md` - Project summary for KOLs/press

### Deployment

Reference `scripts/deploy/` for CI/CD:
- `github_actions.yml` - Full pipeline
- `pre_deploy_checklist.md` - Security validation
- `post_deploy_checklist.md` - Verification steps

### References

- `references/phase0_research_brainstorm.md` - Phase 0 research engine (market, chain scoring, naming, utility)
- `references/cross_chain_mirror.md` - ETH/Base bridging strategy
- `references/tokenomics_template.md` - Full tokenomics design template
- `references/security_checklist.md` - Exploit surface analysis
- `references/regulatory_notes.md` - Compliance considerations
- `references/execution_master_prompt.md` - Full repo generation mode
- `references/aura_ui_engine.md` - Glassmorphic dashboard specs (Module 8)
- `references/narrative_forge.md` - Content strategy engine (Module 9)
- `references/vigilante_security.md` - MEV/sniper protection suite (Module 10)
- `references/propulsion_post_launch.md` - Post-launch growth engine (Module 11)

### Python Engine (Local Execution — 90-99% Token Reduction)

The `engine/` directory contains a Python CLI + MCP server that indexes all 80+ skill files and serves content via byte-offset extraction. No external dependencies (stdlib only).

**CLI Commands** (`python3 -m engine <command>`):

| Command | Description |
|---------|-------------|
| `build-index` | Parse all files → `data/index.json` (~347 entries) |
| `check-index` | Validate index integrity + staleness check |
| `search <query>` | Fuzzy search across all entries |
| `list <category>` | List entries (templates, contracts, references, scripts) |
| `extract <entry-id>` | Extract content by ID with byte offsets |
| `generate-dashboard <dir>` | Write all 55 Aura template files |
| `generate-contracts <dir>` | Write Anchor programs with brief overrides |
| `generate-marketing <dir>` | Write narrative forge content |
| `generate-manifest <dir>` | Write complete repo structure |
| `apply-brief <path>` | Load + validate MEMECOIN_BRIEF.md |
| `token-report` | Show cumulative token savings |
| `serve` | Start MCP stdio server (9 tools) |

**MCP Tools** (auto-registered via `.mcp.json`):
- `memecoin_search` - Fuzzy search across all indexed content
- `memecoin_list_templates` / `memecoin_list_contracts` / `memecoin_list_references` - Category listings
- `memecoin_extract` / `memecoin_extract_template` - Targeted extraction
- `memecoin_generate_dashboard` / `memecoin_generate_contracts` - Bulk file generation
- `memecoin_index_status` - Index stats + freshness

## Execution Mode

For full repo generation with all files (Anchor programs, TypeScript scripts, CI/CD, EVM contracts), reference `references/execution_master_prompt.md`.

**Locked Defaults:**
- Token Supply: 1,000,000,000
- Decimals: 9
- LP Token Amount: 700,000,000 (70%)
- LP USDC Amount: 100,000
- Distribution Wallets: 10

**Phase 0 Trigger:** "research", "brainstorm", "phase 0", or "market analysis"
**Execution Trigger:** "generate full repo", "execution mode", or "DO IT ALL"

When starting a new project, Phase 0 runs first. Skip only if the user provides a pre-existing `MEMECOIN_BRIEF.md` or says "skip research" / "use defaults".

## Deliverables Checklist

When designing a memecoin system, produce:

0. ☐ MEMECOIN_BRIEF.md (Phase 0 research output)
1. ☐ Tokenomics table
2. ☐ Mint + burn flow diagram (ASCII)
3. ☐ Treasury architecture
4. ☐ Liquidity strategy
5. ☐ Governance roadmap
6. ☐ Risk analysis
7. ☐ Smart contract constraints
8. ☐ Deployment checklist
9. ☐ Post-launch growth playbook
10. ☐ Frontend dashboard (Aura UI)
11. ☐ Marketing assets (Narrative Forge)
12. ☐ Security scripts (Vigilante Suite)
13. ☐ Listing applications (Propulsion)

## Global Constraints (Enforce Always)

- No infinite mint
- No hidden admin keys
- All burns deterministic
- Treasury actions logged
- Emergency powers limited + auditable
- LP protection mandatory
- Solana is source of truth for cross-chain
- No chain can mint independently

## Output Format

All deliverables: Markdown (.md), ASCII diagrams, Tables, Copy-paste ready, Production-grade (no hype language)
