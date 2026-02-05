#!/bin/bash
# =============================================================================
# RAYDIUM LP CREATION SCRIPT - INITIAL POOL + ANTI-RUG PROTECTION
# =============================================================================
# This script creates initial liquidity pool on Raydium
# IMPORTANT: Run on mainnet ONLY after thorough devnet testing
# =============================================================================

set -e

# =============================================================================
# CONFIGURATION
# =============================================================================

# Token Configuration (REPLACE THESE)
TOKEN_MINT=""                    # Your memecoin mint address
QUOTE_TOKEN="EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"  # USDC (canonical)
# Alternative: SOL = "So11111111111111111111111111111111111111112"
TOKEN_DECIMALS=9                 # Token decimals (6-9)
QUOTE_DECIMALS=6                 # USDC = 6 decimals, SOL = 9 decimals
INITIAL_TOKEN_AMOUNT=700000000   # 70% of 1B supply (human-readable)
# NOTE: For on-chain operations, multiply by 10^TOKEN_DECIMALS
# e.g., 700000000 tokens * 10^9 = 700000000000000000 raw units
INITIAL_QUOTE_AMOUNT=100000      # $100,000 USDC (human-readable)
# NOTE: For on-chain, multiply by 10^QUOTE_DECIMALS
# e.g., 100000 USDC * 10^6 = 100000000000 raw units

# Wallet Configuration
WALLET_PATH="$HOME/.config/solana/id.json"
RPC_URL="https://api.mainnet-beta.solana.com"

# LP Lock Configuration
LP_LOCK_DURATION=31536000        # 1 year in seconds (minimum recommended)
LP_BURN_INSTEAD=false            # Set true to burn LP tokens instead of lock

# =============================================================================
# VALIDATION
# =============================================================================

validate_config() {
    echo "🔍 Validating configuration..."

    if [ -z "$TOKEN_MINT" ]; then
        echo "❌ ERROR: TOKEN_MINT not set"
        exit 1
    fi

    if [ ! -f "$WALLET_PATH" ]; then
        echo "❌ ERROR: Wallet not found at $WALLET_PATH"
        exit 1
    fi

    # Check wallet balance
    BALANCE=$(solana balance --url $RPC_URL | awk '{print $1}')
    echo "💰 Wallet balance: $BALANCE SOL"

    if (( $(echo "$BALANCE < 1" | bc -l) )); then
        echo "⚠️  WARNING: Low balance. Need SOL for transactions + LP"
    fi

    echo "✅ Configuration valid"
}

# =============================================================================
# TOKEN ACCOUNT SETUP
# =============================================================================

setup_token_accounts() {
    echo ""
    echo "🏦 Setting up token accounts..."

    # Create Associated Token Account for memecoin
    echo "Creating ATA for memecoin..."
    spl-token create-account $TOKEN_MINT --url $RPC_URL

    # Check token balance
    TOKEN_BALANCE=$(spl-token balance $TOKEN_MINT --url $RPC_URL)
    echo "📊 Token balance: $TOKEN_BALANCE"

    if (( $(echo "$TOKEN_BALANCE < $INITIAL_TOKEN_AMOUNT" | bc -l) )); then
        echo "❌ ERROR: Insufficient token balance for LP"
        exit 1
    fi

    echo "✅ Token accounts ready"
}

# =============================================================================
# RAYDIUM POOL CREATION
# =============================================================================

create_raydium_pool() {
    echo ""
    echo "🌊 Creating Raydium liquidity pool..."
    echo ""
    echo "Pool Parameters:"
    echo "  Token A (Memecoin): $TOKEN_MINT"
    echo "  Token B (Quote):    $QUOTE_TOKEN"
    echo "  Token A Amount:     $INITIAL_TOKEN_AMOUNT"
    echo "  Token B Amount:     $INITIAL_QUOTE_AMOUNT"
    echo ""

    # Using Raydium CLI or SDK
    # NOTE: This is a placeholder - actual implementation depends on Raydium SDK version

    cat << 'EOF'
# ============================================================
# RAYDIUM POOL CREATION (Manual Steps or SDK)
# ============================================================
#
# Option 1: Raydium UI (Recommended for first-timers)
#   1. Go to https://raydium.io/liquidity/create-pool/
#   2. Connect wallet
#   3. Select your token and quote token
#   4. Set initial amounts
#   5. Create pool
#
# Option 2: Raydium SDK (Programmatic)
#   npm install @raydium-io/raydium-sdk
#
#   const { Raydium } = require('@raydium-io/raydium-sdk');
#
#   // Initialize
#   const raydium = await Raydium.load({
#     connection,
#     owner: wallet,
#     cluster: 'mainnet'
#   });
#
#   // Create AMM pool
#   const { txId } = await raydium.liquidity.createPoolV4({
#     baseMint: new PublicKey(TOKEN_MINT),
#     quoteMint: new PublicKey(QUOTE_TOKEN),
#     baseAmount: new BN(INITIAL_TOKEN_AMOUNT),
#     quoteAmount: new BN(INITIAL_QUOTE_AMOUNT),
#   });
#
# ============================================================
EOF

    echo ""
    echo "⚠️  IMPORTANT: Record the following after pool creation:"
    echo "   - AMM ID (Pool Address)"
    echo "   - LP Token Mint Address"
    echo "   - Pool Open Time"
}

# =============================================================================
# LP TOKEN PROTECTION (CRITICAL ANTI-RUG)
# =============================================================================

protect_lp_tokens() {
    echo ""
    echo "🔒 LP Token Protection..."
    echo ""

    if [ "$LP_BURN_INSTEAD" = true ]; then
        burn_lp_tokens
    else
        lock_lp_tokens
    fi
}

burn_lp_tokens() {
    echo "🔥 BURNING LP TOKENS (Permanent!)"
    echo ""
    echo "This will permanently burn LP tokens, making liquidity IRREMOVABLE."
    echo ""
    read -p "Type 'BURN' to confirm: " confirm

    if [ "$confirm" != "BURN" ]; then
        echo "Aborted."
        exit 1
    fi

    # Burn LP tokens
    # LP_MINT should be set after pool creation
    if [ -z "$LP_MINT" ]; then
        echo "❌ ERROR: LP_MINT not set. Set it after pool creation."
        exit 1
    fi

    LP_BALANCE=$(spl-token balance $LP_MINT --url $RPC_URL)
    echo "Burning $LP_BALANCE LP tokens..."

    spl-token burn $LP_MINT $LP_BALANCE --url $RPC_URL

    echo "✅ LP tokens burned permanently!"
    echo ""
    echo "🔥 LIQUIDITY IS NOW PERMANENTLY LOCKED"
}

lock_lp_tokens() {
    echo "🔐 LOCKING LP TOKENS"
    echo ""
    echo "Lock Duration: $LP_LOCK_DURATION seconds (~$((LP_LOCK_DURATION/86400)) days)"
    echo ""

    cat << 'EOF'
# ============================================================
# LP TOKEN LOCKING OPTIONS
# ============================================================
#
# Option 1: Streamflow (Recommended)
#   https://streamflow.finance/
#   - Create vesting contract for LP tokens
#   - Set cliff = LP_LOCK_DURATION
#   - Beneficiary = Dead address or team multisig
#
# Option 2: Custom Time-Lock Program
#   Deploy Anchor program with:
#   - PDA holds LP tokens
#   - Unlock timestamp in future
#   - No early withdrawal function
#
# Option 3: LP Locker Services
#   - Unicrypt
#   - Team.finance
#   - DxSale (if available for Solana)
#
# ============================================================
EOF

    echo ""
    echo "⚠️  CRITICAL: Verify lock on-chain before announcing!"
}

# =============================================================================
# JUPITER INTEGRATION
# =============================================================================

setup_jupiter_routing() {
    echo ""
    echo "🪐 Jupiter Integration..."
    echo ""

    cat << 'EOF'
# ============================================================
# JUPITER AUTO-ROUTING
# ============================================================
#
# Jupiter automatically indexes Raydium pools.
# After pool creation, your token will be available on:
#   https://jup.ag/
#
# Verification Steps:
#   1. Wait ~5-10 minutes after pool creation
#   2. Search your token mint on jup.ag
#   3. Verify routing is active
#
# Advanced: Jupiter Limit Orders
#   - Available automatically for indexed tokens
#   - Users can set limit orders via jup.ag
#
# ============================================================
EOF
}

# =============================================================================
# POST-LAUNCH VERIFICATION
# =============================================================================

verify_launch() {
    echo ""
    echo "✅ POST-LAUNCH VERIFICATION CHECKLIST"
    echo ""
    echo "☐ Pool visible on Raydium"
    echo "☐ Token searchable on Jupiter"
    echo "☐ LP tokens locked/burned (verify on-chain!)"
    echo "☐ Mint authority revoked"
    echo "☐ Freeze authority revoked"
    echo "☐ Token metadata correct"
    echo "☐ Socials linked (Twitter, Telegram, Website)"
    echo ""
    echo "🔍 Verification Commands:"
    echo ""
    echo "# Check mint authority"
    echo "spl-token display $TOKEN_MINT --url $RPC_URL"
    echo ""
    echo "# Check LP balance (should be 0 or in lock contract)"
    echo "spl-token balance \$LP_MINT --url $RPC_URL"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    echo "═══════════════════════════════════════════════════════════"
    echo "   RAYDIUM LP CREATION - ANTI-RUG MEMECOIN LAUNCH"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    validate_config
    setup_token_accounts
    create_raydium_pool

    echo ""
    echo "⏳ After pool creation, set LP_MINT and run:"
    echo "   LP_MINT=<your_lp_mint> $0 --protect-lp"
    echo ""

    if [ "$1" = "--protect-lp" ]; then
        protect_lp_tokens
    fi

    setup_jupiter_routing
    verify_launch

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "   LAUNCH COMPLETE - VERIFY EVERYTHING ON-CHAIN!"
    echo "═══════════════════════════════════════════════════════════"
}

# Route to appropriate function
main "$@"
