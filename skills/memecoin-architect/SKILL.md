---
name: memecoin-architect
description: Production-grade memecoin system architect for Solana, Base, and Ethereum. This skill should be used when designing tokenomics, writing Anchor smart contracts, creating Pump-style launch mechanics, building liquidity strategies, implementing burn mechanics, treasury systems, governance, dashboards, CI/CD pipelines, or cross-chain mirror deployments. Triggers on memecoin design, token launch, Solana token, Anchor contracts, DEX liquidity, anti-rug mechanics, or viral token architecture.
---

# Memecoin Architect

Production-grade memecoin system design for Solana (primary), Base, and Ethereum.

This is NOT a "mint & pray" system. This is **follow-the-money architecture**.

## Core Principles

- No infinite mint
- Burns tied to activity (deterministic)
- Treasury governed, not rug-able
- Emergency controls (limited + auditable)
- On-chain metrics visible

## Chain Selection (2026 Reality)

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

### Deployment

Reference `scripts/deploy/` for CI/CD:
- `github_actions.yml` - Full pipeline
- `pre_deploy_checklist.md` - Security validation
- `post_deploy_checklist.md` - Verification steps

### References

- `references/cross_chain_mirror.md` - ETH/Base bridging strategy
- `references/tokenomics_template.md` - Full tokenomics design template
- `references/security_checklist.md` - Exploit surface analysis
- `references/regulatory_notes.md` - Compliance considerations
- `references/execution_master_prompt.md` - Full repo generation mode

## Execution Mode

For full repo generation with all files (Anchor programs, TypeScript scripts, CI/CD, EVM contracts), reference `references/execution_master_prompt.md`.

**Locked Defaults:**
- Token Supply: 1,000,000,000
- Decimals: 9
- LP Token Amount: 700,000,000 (70%)
- LP USDC Amount: 100,000
- Distribution Wallets: 10

**Trigger:** "generate full repo", "execution mode", or "DO IT ALL"

## Deliverables Checklist

When designing a memecoin system, produce:

1. ☐ Tokenomics table
2. ☐ Mint + burn flow diagram (ASCII)
3. ☐ Treasury architecture
4. ☐ Liquidity strategy
5. ☐ Governance roadmap
6. ☐ Risk analysis
7. ☐ Smart contract constraints
8. ☐ Deployment checklist
9. ☐ Post-launch growth playbook

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
