"use client";

// =============================================================================
// useTokenMetrics — MintState + BurnState on-chain data
// =============================================================================

import { useQuery } from "@tanstack/react-query";
import { useConnection } from "@solana/wallet-adapter-react";
import { PublicKey } from "@solana/web3.js";
import { fetchAccountData } from "@/lib/anchor-client";
import { TOKEN_MINT, REFETCH_INTERVAL, TOTAL_SUPPLY } from "@/lib/constants";

// Matches Anchor MintState account
interface MintState {
    totalSupply: bigint;
    decimals: number;
    minted: boolean;
    authority: PublicKey;
}

// Matches Anchor BurnState account
interface BurnState {
    totalBurned: bigint;
    cumulativeVolume: bigint;
    milestonesReached: number;
    tradeBurnBps: number;
    paused: boolean;
}

export interface TokenMetrics {
    totalSupply: number;
    totalBurned: number;
    circulatingSupply: number;
    burnPercent: number;
    tradeBurnBps: number;
    milestonesReached: number;
    burnPaused: boolean;
}

function derivePDA(seeds: (Buffer | Uint8Array)[], programId: PublicKey): PublicKey {
    const [pda] = PublicKey.findProgramAddressSync(seeds, programId);
    return pda;
}

export function useTokenMetrics() {
    const { connection } = useConnection();

    return useQuery<TokenMetrics>({
        queryKey: ["tokenMetrics", TOKEN_MINT.toBase58()],
        queryFn: async () => {
            const programId = new PublicKey(process.env.NEXT_PUBLIC_PROGRAM_ID || PublicKey.default.toBase58());

            const mintStatePDA = derivePDA(
                [Buffer.from("mint_state"), TOKEN_MINT.toBuffer()],
                programId,
            );
            const burnStatePDA = derivePDA(
                [Buffer.from("burn_state"), TOKEN_MINT.toBuffer()],
                programId,
            );

            const [mintState, burnState] = await Promise.all([
                fetchAccountData<MintState>(connection, mintStatePDA, "mintState"),
                fetchAccountData<BurnState>(connection, burnStatePDA, "burnState"),
            ]);

            const totalBurned = Number(burnState.totalBurned);
            const totalSupply = Number(mintState.totalSupply) || TOTAL_SUPPLY;
            const circulatingSupply = totalSupply - totalBurned;

            return {
                totalSupply,
                totalBurned,
                circulatingSupply,
                burnPercent: (totalBurned / totalSupply) * 100,
                tradeBurnBps: burnState.tradeBurnBps,
                milestonesReached: burnState.milestonesReached,
                burnPaused: burnState.paused,
            };
        },
        refetchInterval: REFETCH_INTERVAL,
        staleTime: REFETCH_INTERVAL / 2,
    });
}
