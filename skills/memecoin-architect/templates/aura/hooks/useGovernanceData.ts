"use client";

// =============================================================================
// useGovernanceData — GovernanceMultisig on-chain state
// =============================================================================

import { useQuery } from "@tanstack/react-query";
import { useConnection } from "@solana/wallet-adapter-react";
import { PublicKey } from "@solana/web3.js";
import { fetchAccountData } from "@/lib/anchor-client";
import { REFETCH_INTERVAL } from "@/lib/constants";

export interface GovernanceProposal {
    proposalType: string;
    proposer: string;
    approvals: string[];
    executed: boolean;
    createdAt: number;
}

export interface GovernanceData {
    owners: string[];
    threshold: number;
    spendCapPerTx: number;
    proposals: GovernanceProposal[];
}

// Matches Anchor GovernanceState account
interface GovernanceState {
    owners: PublicKey[];
    threshold: number;
    spendCapPerTx: bigint;
    proposals: {
        proposalType: { transfer?: object; configChange?: object };
        proposer: PublicKey;
        approvals: PublicKey[];
        executed: boolean;
        createdAt: bigint;
    }[];
}

function deriveGovernancePDA(programId: PublicKey): PublicKey {
    const [pda] = PublicKey.findProgramAddressSync(
        [Buffer.from("governance")],
        programId,
    );
    return pda;
}

export function useGovernanceData() {
    const { connection } = useConnection();

    return useQuery<GovernanceData>({
        queryKey: ["governanceData"],
        queryFn: async () => {
            const programId = new PublicKey(process.env.NEXT_PUBLIC_PROGRAM_ID || PublicKey.default.toBase58());
            const governancePDA = deriveGovernancePDA(programId);

            const state = await fetchAccountData<GovernanceState>(
                connection, governancePDA, "governanceState",
            );

            return {
                owners: state.owners.map((o) => o.toBase58()),
                threshold: state.threshold,
                spendCapPerTx: Number(state.spendCapPerTx),
                proposals: state.proposals.map((p) => ({
                    proposalType: p.proposalType.transfer ? "transfer" : "configChange",
                    proposer: p.proposer.toBase58(),
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
