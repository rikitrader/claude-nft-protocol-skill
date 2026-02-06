// =============================================================================
// AURA CONSTANTS — Program IDs, RPC Endpoints, Config
// =============================================================================
// All public-facing constants for the Aura dashboard.
// Values are loaded from environment variables at build time.
// =============================================================================

import { PublicKey } from "@solana/web3.js";

// =============================================================================
// NETWORK
// =============================================================================

export const RPC_ENDPOINT =
    process.env.NEXT_PUBLIC_RPC_ENDPOINT || "https://api.mainnet-beta.solana.com";

export const NETWORK = (process.env.NEXT_PUBLIC_NETWORK || "mainnet-beta") as
    | "mainnet-beta"
    | "devnet"
    | "testnet";

// =============================================================================
// PROGRAM IDS
// =============================================================================

export const TOKEN_MINT = new PublicKey(
    process.env.NEXT_PUBLIC_TOKEN_MINT || "11111111111111111111111111111111"
);

export const PROGRAM_ID = new PublicKey(
    process.env.NEXT_PUBLIC_PROGRAM_ID || "11111111111111111111111111111111"
);

export const TREASURY_PDA = new PublicKey(
    process.env.NEXT_PUBLIC_TREASURY_PDA || "11111111111111111111111111111111"
);

// =============================================================================
// EXTERNAL APIs
// =============================================================================

export const JUPITER_PRICE_API = "https://api.jup.ag/price/v2";

// =============================================================================
// UI DEFAULTS
// =============================================================================

export const TOTAL_SUPPLY = 1_000_000_000;
export const DECIMALS = 9;
export const TICKER = process.env.NEXT_PUBLIC_TICKER || "TOKEN";

/** TanStack Query refetch interval for on-chain data (ms) */
export const REFETCH_INTERVAL = 10_000;

// =============================================================================
// PDA SEEDS (must match Anchor program seeds)
// =============================================================================

export const PDA_SEEDS = {
    mintState: "mint_state",
    burnState: "burn_state",
    treasury: "treasury",
    governance: "governance",
    emergency: "emergency",
} as const;
