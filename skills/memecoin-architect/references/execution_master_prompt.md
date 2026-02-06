# Execution Master Prompt — Full Repo Generation Mode

When triggered with full execution mode, generate a complete, repo-ready memecoin system.

## System Configuration

```
SYSTEM:
You are a production-grade blockchain protocol team that outputs REAL code.
No pseudocode. No placeholders. No "high-level only".
All outputs must be copy/paste compilable and repo-ready.

PRIMARY CHAIN: Solana
SMART CONTRACTS: Anchor (Rust)
TOKEN STANDARD: token_interface (compatible with both SPL Token and Token-2022)
DEX: Raydium + Jupiter
CI/CD: GitHub Actions
MIRROR CHAINS: Ethereum + Base (EVM)
CANONICAL SUPPLY: Solana ONLY (EVM tokens are wrapped mirrors)
```

## Phase 0 Dependency

Execution mode works best with a `MEMECOIN_BRIEF.md` from Phase 0.

**If brief exists:** Use brief values (Section 7: "Design Parameters") to override
the locked defaults below. The brief provides token name, ticker, chain selection,
and any parameter overrides derived from market research.

**If brief does NOT exist:** Prompt the user:
> "No MEMECOIN_BRIEF.md found. Options:
> 1. Run Phase 0 first (recommended) — say 'phase 0' or 'research'
> 2. Proceed with locked defaults (skip research)
> 3. Provide a brief manually"

When proceeding without a brief, all locked defaults apply and a WARNING
is included in the generated README.md:
> "NOTE: This repo was generated without Phase 0 research. Market fit,
> naming, and chain selection were not validated."

## Research-Backed Defaults (Locked)

> These defaults are used when no `MEMECOIN_BRIEF.md` is provided.
> When a brief exists, values from Section 7 ("Design Parameters")
> of the brief take precedence.

| Parameter | Value | Notes |
|-----------|-------|-------|
| Token Supply | 1,000,000,000 | Fixed, immutable |
| Decimals | 9 | Solana/SPL standard |
| Distribution Wallets | 10 | For initial distribution |
| Token to LP | 700,000,000 | 70% of supply |
| USDC to LP | 100,000 | Initial liquidity |
| LP Handling | Burn OR Lock | 6-12 months minimum |

## Required Output Artifacts

> **NOTE:** The artifacts below are GENERATION TARGETS — they do not exist as pre-built files
> in this skill. When "execution mode" is triggered, the AI generates all files listed below.
> Pre-existing reference code lives in `scripts/anchor_contracts/` and `references/`.

### Repo Tree (Exact Structure)

```
/repo
  /MEMECOIN_BRIEF.md          # Phase 0 output (if available)
  /Anchor.toml
  /Cargo.toml
  /package.json
  /tsconfig.json
  /README.md

  /programs
    /token_mint
      /Cargo.toml
      /src/lib.rs
    /burn_controller
      /Cargo.toml
      /src/lib.rs
    /treasury_vault
      /Cargo.toml
      /src/lib.rs
    /governance_multisig
      /Cargo.toml
      /src/lib.rs
    /emergency_pause
      /Cargo.toml
      /src/lib.rs

  /migrations
    /deploy.ts

  /scripts
    /00_env_check.ts
    /01_create_spl_mint.ts
    /02_mint_and_distribute.ts
    /03_revoke_authorities.ts
    /04_create_raydium_pool.ts
    /05_add_liquidity_raydium.ts
    /06_lock_or_burn_lp.ts
    /07_verify_jupiter_quote.ts
    /08_swap_smoke_test.ts

  /.github/workflows
    /ci.yml
    /release.yml

  /evm
    /foundry.toml
    /src/WrappedMeme.sol
    /src/MirrorBridgeGate.sol
    /test/Bridge.t.sol
    /README.md

  /frontend                          # Module 8: Aura Dashboard Engine
    /package.json
    /tsconfig.json
    /next.config.ts
    /tailwind.config.ts
    /.env.example
    /src
      /app
        /layout.tsx                  # Root layout + fonts + providers
        /globals.css                 # Design tokens + glassmorphic utils
        /(landing)                   # Route group: marketing page
          /layout.tsx                # Minimal landing layout
          /page.tsx                  # Landing page (hero, features, tokenomics)
        /(dashboard)                 # Route group: holder + admin views
          /layout.tsx                # Sidebar nav + wallet header
          /page.tsx                  # Holder dashboard (bento grid, live data)
          /admin
            /layout.tsx              # Admin tabs + RoleGuard wrapper
            /page.tsx                # Admin overview (system status)
            /treasury/page.tsx       # Treasury proposals + create form
            /governance/page.tsx     # Multi-sig config + proposals
            /emergency/page.tsx      # Pause/resume voting
            /burns/page.tsx          # Burn metrics + buyback form
      /components
        /QueryProvider.tsx           # TanStack Query client wrapper
        /GlassCard.tsx               # Reusable glassmorphic card
        /BurnMeter.tsx               # Animated burn ring
        /PriceCard.tsx               # Price display + 24h change
        /landing
          /HeroSection.tsx           # Animated hero with live price
          /FeatureGrid.tsx           # 6 feature cards
          /FeatureCard.tsx           # Single feature card
          /TokenomicsSection.tsx     # Distribution overview
          /DistributionChart.tsx     # Recharts PieChart
          /SecurityBadges.tsx        # Verified-on-chain badges
          /SecurityBadge.tsx         # Single badge
          /CTASection.tsx            # Call-to-action block
          /Footer.tsx                # Footer + disclaimers
          /SocialLinks.tsx           # Social media icons
        /dashboard
          /TreasuryCard.tsx          # Balance + threshold
          /PriceChart.tsx            # Candlestick via Recharts
          /HolderMap.tsx             # Top 10 holders
          /LPStatus.tsx              # LP lock countdown
          /SupplyTicker.tsx          # Circulating + burned supply
        /admin
          /RoleGuard.tsx             # Wallet-gated access control
          /AdminCard.tsx             # Card variant with action header
          /ProposalList.tsx          # Treasury proposal list
          /ProposalCard.tsx          # Single proposal display
          /TransactionButton.tsx     # Send + confirm button
          /CreateProposalForm.tsx    # New transfer proposal form
          /GovernanceConfigPanel.tsx # Owners, threshold, config
          /EmergencyControls.tsx     # Vote pause/resume UI
          /BuybackBurnForm.tsx       # Treasury buyback + burn
        /shared
          /AnimatedNumber.tsx        # Framer Motion counter
          /Sparkline.tsx             # Tiny inline area chart
          /StatusBadge.tsx           # Active/Paused/Locked pill
        /wallet
          /WalletProvider.tsx        # Solana wallet adapter wrapper
          /ConnectButton.tsx         # Styled connect button
      /hooks
        /useTokenMetrics.ts          # MintState + BurnState PDAs
        /useTreasuryData.ts          # TreasuryState PDA
        /useGovernanceData.ts        # GovernanceState PDA
        /useEmergencyStatus.ts       # EmergencyState PDA
        /usePriceData.ts             # Jupiter price feed
        /useRoleGuard.ts             # Wallet role detection
      /lib
        /anchor-client.ts            # IDL + program connection
        /constants.ts                # Program IDs, RPC endpoints, PDA seeds
        /formatters.ts               # Number, address, time formatters

  /scripts
    /security                        # Module 10: Vigilante Suite
      /jito_lp_add.ts               # JITO-bundled LP addition
      /lock_metadata.ts             # Metadata immutability script
      /verify_authorities.ts        # Post-deploy authority checker
      /anti_sniper_config.ts        # Anti-bot tier configuration

  /marketing                         # Module 9: Narrative Forge
    /threads
      /launch_thread.md              # 5-part X/Twitter alpha thread
      /milestone_thread.md           # Burn/holder milestone template
    /announcements
      /telegram_launch.md            # Telegram announcement
      /discord_launch.md             # Discord embed format
    /visuals
      /meme_prompts.md               # 10 DALL-E/Midjourney prompts
      /brand_guide.md                # Colors, fonts, logo rules
    /whitepaper
      /whitepaper_template.md        # Structured whitepaper
    /media_kit
      /one_pager.md                  # Single-page project summary

  /growth                            # Module 11: Propulsion
    /dex_trackers
      /dexscreener_setup.md          # Profile claim guide
      /dextools_setup.md             # DEXT Force listing guide
    /listings
      /coingecko_application.md      # CG listing checklist
      /cmc_application.md            # CMC listing checklist
      /jupiter_strict.md             # Jupiter strict list app
    /outreach
      /kol_research_brief.md         # KOL identification template
    /community
      /growth_playbook.md            # 30-day growth plan
```

## Program Requirements

All programs MUST include:
- Anchor error codes
- Events (`emit!()`) for critical actions
- PDA seeds documented in code comments
- Explicit access control checks
- Pause checks where relevant
- Spend caps & rate limits where relevant
- Deterministic behavior (no hidden admin backdoors)

### Global Security Rules

1. **FIXED SUPPLY**: Mint only once. After distribution, mint authority = None
2. **FREEZE AUTHORITY**: Must be None (unless explicitly required)
3. **TREASURY**: PDA-owned vault; spends only via Governance approval (CPI)
4. **EMERGENCY**: Pause is time-limited + logged + auditable; cannot mint
5. **BURN**: burn_controller burns from user ATA with user signature + logs event
6. **GOVERNANCE**: Multisig threshold + proposal ledger + execute → treasury spend CPI

## Program Interfaces

### token_mint
```rust
- initialize(mint_pubkey, total_supply, decimals)
- mark_minted_once()
- assert_authorities_revoked(mint_pubkey)
```

### burn_controller
```rust
- burn(amount)  // burns from user ATA, logs BurnEvent
```

### treasury_vault
```rust
- initialize_treasury()
- deposit()     // optional, tracks deposits
- spend(to, amount) // ONLY via governance CPI + cap checks
```

### governance_multisig
```rust
- initialize(owners[], threshold, spend_cap_per_tx)
- propose_spend(to, amount, memo)
- approve(proposal_id)
- execute(proposal_id) -> CPI into treasury_vault::spend
```

### emergency_pause
```rust
- initialize(pause_authority, max_pause_seconds)
- pause(reason_code)
- unpause()
- is_paused() / assert_not_paused() helper
```

## TypeScript Scripts Requirements

Generate deployable TypeScript scripts (Solana web3 + SPL Token) that:

1. Create mint (SPL token) with decimals = 9
2. Create ATAs
3. Mint total supply to deployer, then distribute to 10 wallets
4. Revoke mint authority + revoke freeze authority after distribution
5. Create Raydium pool with exact params
6. Add initial liquidity using locked defaults
7. Lock or burn LP tokens
8. Verify Jupiter quote for TOKEN/USDC
9. Run swap smoke test

### Adaptation Points

Mark exact lines that might change for:
- Pool keys
- Market accounts
- Transaction building
- SDK version differences

## CI/CD Requirements

### ci.yml MUST:
- Install deps
- rustfmt + clippy
- anchor build
- anchor test (local validator)
- TypeScript lint + typecheck
- Generate IDLs and store as artifacts
- Compute deterministic program binary hash

### release.yml MUST:
- Require manual approval step
- Deploy to devnet
- Run post-deploy smoke tests
- Gated promotion to mainnet with checklist enforcement

## Cross-Chain Mirror (ETH/Base)

### WrappedMeme.sol Requirements:
- mint/burn restricted ONLY to MirrorBridgeGate
- No owner mint
- Events for mint/burn

### MirrorBridgeGate.sol Requirements:
- Pluggable verifier interface for "Solana lock proof"
- Mint only upon valid proof
- Burn triggers unlock workflow off-chain
- Rate limits + pause function

### Rules:
- No chain can mint independently
- Supply parity must be enforceable
- Solana remains "source of truth"

## Output Format

1. Start with FILE TREE
2. Output each file as:
```
===== FILE: path/to/file =====
<full contents>
```

3. Include at end:
- Devnet→Mainnet deployment checklist
- Security checklist
- Known adaptation points
- Smoke test commands

## Trigger

When user requests "generate full repo", "execution mode", or "DO IT ALL", output the complete repository with all files and contents.
