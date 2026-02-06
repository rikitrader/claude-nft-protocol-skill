"use client";

// =============================================================================
// useEmergencyStatus — EmergencyPause on-chain state
// =============================================================================

import { useQuery } from "@tanstack/react-query";
import { useConnection } from "@solana/wallet-adapter-react";
import { PublicKey } from "@solana/web3.js";
import { fetchAccountData } from "@/lib/anchor-client";
import { REFETCH_INTERVAL } from "@/lib/constants";

export interface EmergencyStatus {
    isPaused: boolean;
    guardians: string[];
    pauseStartSlot: number;
    pauseEndSlot: number;
    currentSlot: number;
    pauseVotes: string[];
    resumeVotes: string[];
}

// Matches Anchor EmergencyState account
interface EmergencyState {
    guardians: PublicKey[];
    isPaused: boolean;
    pauseStartSlot: bigint;
    pauseEndSlot: bigint;
    pauseVotes: PublicKey[];
    resumeVotes: PublicKey[];
}

function deriveEmergencyPDA(programId: PublicKey): PublicKey {
    const [pda] = PublicKey.findProgramAddressSync(
        [Buffer.from("emergency")],
        programId,
    );
    return pda;
}

export function useEmergencyStatus() {
    const { connection } = useConnection();

    return useQuery<EmergencyStatus>({
        queryKey: ["emergencyStatus"],
        queryFn: async () => {
            const programId = new PublicKey(process.env.NEXT_PUBLIC_PROGRAM_ID || PublicKey.default.toBase58());
            const emergencyPDA = deriveEmergencyPDA(programId);

            const [state, currentSlot] = await Promise.all([
                fetchAccountData<EmergencyState>(connection, emergencyPDA, "emergencyState"),
                connection.getSlot(),
            ]);

            return {
                isPaused: state.isPaused,
                guardians: state.guardians.map((g) => g.toBase58()),
                pauseStartSlot: Number(state.pauseStartSlot),
                pauseEndSlot: Number(state.pauseEndSlot),
                currentSlot,
                pauseVotes: state.pauseVotes.map((v) => v.toBase58()),
                resumeVotes: state.resumeVotes.map((v) => v.toBase58()),
            };
        },
        refetchInterval: REFETCH_INTERVAL,
        staleTime: REFETCH_INTERVAL / 2,
    });
}
