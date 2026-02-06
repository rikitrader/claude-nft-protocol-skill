"use client";

// =============================================================================
// useTreasuryData — TreasuryVault on-chain state
// =============================================================================

import { useQuery } from "@tanstack/react-query";
import { useConnection } from "@solana/wallet-adapter-react";
import { PublicKey } from "@solana/web3.js";
import { fetchAccountData } from "@/lib/anchor-client";
import { REFETCH_INTERVAL } from "@/lib/constants";

export interface Proposal {
    recipient: string;
    amount: number;
    description: string;
    approvals: string[];
    executed: boolean;
    createdAt: number;
}

export interface TreasuryData {
    balance: number;
    signers: string[];
    threshold: number;
    dailySpendCap: number;
    proposals: Proposal[];
}

// Matches Anchor TreasuryState account
interface TreasuryState {
    signers: PublicKey[];
    threshold: number;
    dailySpendCap: bigint;
    proposals: {
        recipient: PublicKey;
        amount: bigint;
        description: string;
        approvals: PublicKey[];
        executed: boolean;
        createdAt: bigint;
    }[];
}

function deriveTreasuryPDA(programId: PublicKey): PublicKey {
    const [pda] = PublicKey.findProgramAddressSync(
        [Buffer.from("treasury")],
        programId,
    );
    return pda;
}

export function useTreasuryData() {
    const { connection } = useConnection();

    return useQuery<TreasuryData>({
        queryKey: ["treasuryData"],
        queryFn: async () => {
            const programId = new PublicKey(process.env.NEXT_PUBLIC_PROGRAM_ID || PublicKey.default.toBase58());
            const treasuryPDA = deriveTreasuryPDA(programId);

            const state = await fetchAccountData<TreasuryState>(
                connection, treasuryPDA, "treasuryState",
            );

            // Fetch SOL balance of the treasury PDA
            const balance = await connection.getBalance(treasuryPDA);

            return {
                balance: balance / 1e9,
                signers: state.signers.map((s) => s.toBase58()),
                threshold: state.threshold,
                dailySpendCap: Number(state.dailySpendCap),
                proposals: state.proposals.map((p) => ({
                    recipient: p.recipient.toBase58(),
                    amount: Number(p.amount),
                    description: p.description,
                    approvals: p.approvals.map((a) => a.toBase58()),
                    executed: p.executed,
                    createdAt: Number(p.createdAt),
                })),
            };
        },
        refetchInterval: REFETCH_INTERVAL,
        staleTime: REFETCH_INTERVAL / 2,
    });
}
