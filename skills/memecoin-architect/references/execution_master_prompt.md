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

## Research-Backed Defaults (Locked)

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
