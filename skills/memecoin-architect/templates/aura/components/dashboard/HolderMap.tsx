"use client";

import React from "react";
import { useQuery } from "@tanstack/react-query";
import { useConnection } from "@solana/wallet-adapter-react";
import { GlassCard } from "@/components/GlassCard";
import { TOKEN_MINT, REFETCH_INTERVAL } from "@/lib/constants";
import { shortenAddress, formatNumber } from "@/lib/formatters";

export function HolderMap() {
    const { connection } = useConnection();

    const { data: holders, isLoading } = useQuery({
        queryKey: ["topHolders", TOKEN_MINT.toBase58()],
        queryFn: async () => {
            const result = await connection.getTokenLargestAccounts(TOKEN_MINT);
            return result.value.slice(0, 10).map((account) => ({
                address: account.address.toBase58(),
                amount: Number(account.amount) / 1e9,
            }));
        },
        refetchInterval: REFETCH_INTERVAL * 6, // 60s — heavier RPC call
        staleTime: REFETCH_INTERVAL * 3,
    });

    return (
        <GlassCard title="Top Holders">
            {isLoading ? (
                <div className="h-48 animate-pulse rounded-lg bg-white/5" />
            ) : (
                <div className="space-y-2">
                    {holders?.map((h, i) => (
                        <div key={h.address} className="flex items-center gap-2 text-sm">
                            <span className="w-5 text-right text-xs text-white/30">{i + 1}</span>
                            <span className="font-mono text-white/60">{shortenAddress(h.address)}</span>
                            <span className="ml-auto font-bold text-white">{formatNumber(h.amount)}</span>
                        </div>
                    ))}
                </div>
            )}
        </GlassCard>
    );
}
