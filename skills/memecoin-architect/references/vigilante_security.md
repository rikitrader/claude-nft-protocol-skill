# Module 10: "Vigilante" Security Suite

## Purpose

Provide next-generation on-chain protection for fair token launches on Solana. This module addresses the MEV / sniper / bot attack surface that exists during the critical first minutes of liquidity addition. All protections are deterministic, time-bounded, and auditable.

## Threat Model

```
┌─────────────────────────────────────────────────────────────┐
│              LAUNCH ATTACK SURFACE                            │
├──────────────────┬──────────────────────────────────────────┤
│ SNIPERS          │ Bots that buy in the same block as LP    │
│                  │ addition, front-running real users        │
├──────────────────┼──────────────────────────────────────────┤
│ SANDWICH ATTACKS │ MEV bots that wrap user swaps with       │
│                  │ buy-before / sell-after for profit        │
├──────────────────┼──────────────────────────────────────────┤
│ METADATA RUGS    │ Token metadata changed post-launch to    │
│                  │ impersonate another project               │
├──────────────────┼──────────────────────────────────────────┤
│ AUTHORITY RUGS   │ Mint/freeze authority retained post-     │
│                  │ launch, enabling infinite mint            │
├──────────────────┼──────────────────────────────────────────┤
│ WASH TRADING     │ Bots creating fake volume to trigger     │
│                  │ DEXScreener trending                     │
├──────────────────┼──────────────────────────────────────────┤
│ COPY TOKENS      │ Fake tokens with same name/ticker        │
│                  │ deployed to steal buyers                 │
└──────────────────┴──────────────────────────────────────────┘
```

## Protection Modules

### 1. JITO-Aware Liquidity Addition

Use Jito bundles to add liquidity atomically and privately, preventing sniper bots from detecting the LP addition in the public mempool.

```
JITO BUNDLE FLOW:
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Build LP TX │───→│ Submit via  │───→│ LP added in │
│ locally     │    │ Jito bundle │    │ private     │
│             │    │ (tip: 0.01  │    │ block space │
│             │    │  SOL)       │    │             │
└─────────────┘    └─────────────┘    └─────────────┘
                   No public mempool exposure
```

**Script: `scripts/security/jito_lp_add.ts`**

Requirements:
- Use `@jito-foundation/jito-ts` SDK
- Bundle contains: create pool + add liquidity + (optional) first swap
- Tip amount configurable (default: 0.01 SOL)
- Fallback to standard TX if Jito is unavailable
- Retry logic with exponential backoff (max 3 attempts)

```typescript
// Pseudocode structure
// 1. Build createPool instruction (Raydium)
// 2. Build addLiquidity instruction
// 3. Bundle both into Jito bundle
// 4. Submit to Jito block engine
// 5. Wait for confirmation
// 6. Verify pool state on-chain
```

### 2. Anti-Bot: Time-Weighted Swap Caps

Enforce maximum swap sizes during the first N minutes after LP addition. This prevents bots from buying massive positions in early blocks.

```
ANTI-BOT TIMELINE:
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│  T+0 min    T+5 min    T+10 min   T+30 min   T+∞          │
│  ├──────────┼──────────┼──────────┼──────────┤              │
│  │ MAX 0.1% │ MAX 0.5% │ MAX 1%   │ MAX 2%   │ NO CAP     │
│  │ of supply│ of supply│ of supply│ of supply│             │
│  │          │          │          │          │              │
│  │ Cooldown:│ Cooldown:│ Cooldown:│ Cooldown:│              │
│  │ 60s/addr │ 30s/addr │ 15s/addr │ None     │              │
│  └──────────┴──────────┴──────────┴──────────┘              │
│                                                              │
│  PROTECTION WINDOW: Configurable (default: 30 minutes)      │
│  After window expires: All caps removed automatically       │
└─────────────────────────────────────────────────────────────┘
```

**Implementation: Anchor Program Extension**

```rust
// anti_sniper.rs — Program extension for token_mint
//
// State:
//   launch_timestamp: i64      — set when LP is added
//   protection_window: i64     — duration in seconds (default: 1800)
//   tier_caps: [SwapCap; 4]    — max % per tier
//   tier_cooldowns: [i64; 4]   — cooldown per address per tier
//   last_swap: HashMap<Pubkey, i64>  — per-address cooldown tracking
//
// Instructions:
//   activate_protection(launch_ts, window, caps, cooldowns)
//   check_swap_allowed(buyer, amount) -> bool
//   deactivate_protection() — auto after window expires
//
// Events:
//   ProtectionActivated { timestamp, window, caps }
//   SwapBlocked { buyer, amount, reason, tier }
//   ProtectionDeactivated { timestamp, total_blocked }
```

**Swap Cap Tiers (Defaults):**

| Tier | Time Window | Max per Swap | Cooldown per Address |
|------|-------------|-------------|---------------------|
| 1 | 0-5 min | 0.1% of supply | 60 seconds |
| 2 | 5-10 min | 0.5% of supply | 30 seconds |
| 3 | 10-30 min | 1% of supply | 15 seconds |
| 4 | 30+ min | 2% of supply | None |
| Post-window | After protection_window | No cap | None |

### 3. Metadata Immutability

One-click scripts to permanently lock token metadata and revoke update authority.

**Script: `scripts/security/lock_metadata.ts`**

```
METADATA LOCK FLOW:
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│  Step 1: Verify current metadata is correct                 │
│          - Name matches expected                             │
│          - Symbol matches expected                           │
│          - URI points to correct JSON                        │
│          - Image in JSON is correct                          │
│                                                              │
│  Step 2: Set metadata to immutable                           │
│          - Metaplex: set isMutable = false                   │
│          - Token-2022: remove metadata update authority       │
│                                                              │
│  Step 3: Revoke update authority                             │
│          - SetAuthority(UpdateMetadata, None)                │
│                                                              │
│  Step 4: Verify on-chain                                     │
│          - Confirm isMutable == false                         │
│          - Confirm updateAuthority == None                    │
│          - Log verification TX signature                     │
│                                                              │
│  IRREVERSIBLE: Cannot be undone after execution              │
└─────────────────────────────────────────────────────────────┘
```

**Supports both token standards:**

| Standard | Method | Library |
|----------|--------|---------|
| SPL Token (Metaplex) | `updateMetadataAccountV2` with `isMutable: false` | `@metaplex-foundation/mpl-token-metadata` |
| Token-2022 | Remove metadata authority via `setAuthority` | `@solana/spl-token` |

### 4. Authority Verification Script

Comprehensive post-deploy check that all dangerous authorities are revoked.

**Script: `scripts/security/verify_authorities.ts`**

```
AUTHORITY CHECKLIST:
┌──────────────────────┬───────────────┬──────────┐
│ Authority             │ Expected      │ Status   │
├──────────────────────┼───────────────┼──────────┤
│ Mint Authority        │ None          │ ✅ / ❌  │
│ Freeze Authority      │ None          │ ✅ / ❌  │
│ Metadata Update Auth  │ None          │ ✅ / ❌  │
│ Metadata isMutable    │ false         │ ✅ / ❌  │
│ Token Account Owner   │ PDA (program) │ ✅ / ❌  │
│ LP Lock Status        │ Locked/Burned │ ✅ / ❌  │
└──────────────────────┴───────────────┴──────────┘

EXIT CODE:
  0 = All checks passed
  1 = One or more checks failed (blocks deployment)
```

### 5. Sandwich Attack Mitigation

Configuration guidance for protecting users from MEV sandwich attacks.

```
SANDWICH PROTECTION STRATEGIES:
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│  1. JITO TIP TRANSACTIONS                                   │
│     Users submit swaps via Jito bundles                     │
│     Cost: ~0.001-0.01 SOL tip                               │
│     Protection: Swap executes in private block space         │
│                                                              │
│  2. SLIPPAGE CONFIGURATION                                   │
│     Default UI slippage: 0.5% (not auto-unlimited)          │
│     Dashboard warning if slippage > 2%                      │
│     Tooltip explaining sandwich risk                        │
│                                                              │
│  3. PRIORITY FEE GUIDANCE                                    │
│     Recommend compute unit price for fast inclusion          │
│     Without Jito: higher priority = less time in mempool    │
│                                                              │
│  4. JUPITER INTEGRATION                                      │
│     Jupiter v6 has built-in MEV protection                  │
│     Route through Jupiter API for automatic protection      │
│     Use exact-out mode where possible                       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Repo Tree (Security Additions)

```
/repo
  /scripts
    /security
      /jito_lp_add.ts            # JITO-bundled LP addition
      /lock_metadata.ts          # Metadata immutability script
      /verify_authorities.ts     # Post-deploy authority checker
      /anti_sniper_config.ts     # Anti-bot tier configuration

  /programs
    /anti_sniper                 # Optional Anchor program
      /Cargo.toml
      /src/lib.rs                # Time-weighted swap caps
```

## Configuration

### Anti-Sniper Defaults

```json
{
  "protection_window_seconds": 1800,
  "tiers": [
    { "duration_minutes": 5,  "max_pct": 0.1, "cooldown_seconds": 60 },
    { "duration_minutes": 10, "max_pct": 0.5, "cooldown_seconds": 30 },
    { "duration_minutes": 30, "max_pct": 1.0, "cooldown_seconds": 15 },
    { "duration_minutes": -1, "max_pct": 2.0, "cooldown_seconds": 0 }
  ],
  "jito_tip_lamports": 10000000,
  "fallback_to_standard_tx": true,
  "auto_deactivate": true
}
```

### Metadata Lock Checklist

| Step | Action | Reversible? |
|------|--------|-------------|
| 1 | Verify metadata content | Yes |
| 2 | Set isMutable = false | NO |
| 3 | Revoke update authority | NO |
| 4 | Verify on-chain | N/A |

## CI/CD Integration

Add to `/.github/workflows/ci.yml`:

```yaml
# Security verification step (post-deploy)
verify-authorities:
  runs-on: ubuntu-latest
  needs: deploy
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: '20'
    - run: npm ci
    - run: npx ts-node scripts/security/verify_authorities.ts
      env:
        RPC_URL: ${{ secrets.RPC_URL }}
        TOKEN_MINT: ${{ secrets.TOKEN_MINT }}
```

## Security Rules

1. **Protection window is configurable but defaults to 30 minutes** — enough to deter snipers without frustrating real users
2. **Caps are per-address** — prevents Sybil circumvention (one wallet, many small buys work but are rate-limited by cooldown)
3. **Auto-deactivation is mandatory** — protection MUST expire; permanent caps would kill liquidity
4. **JITO is preferred but not required** — standard TX fallback ensures functionality on any RPC
5. **Metadata lock is IRREVERSIBLE** — script includes confirmation prompt and dry-run mode
6. **Authority revocation is ATOMIC** — included in the existing `mint_and_revoke` flow from token_mint.rs
