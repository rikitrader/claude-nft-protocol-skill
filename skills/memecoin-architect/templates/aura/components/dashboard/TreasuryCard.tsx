"use client";

import React from "react";
import { GlassCard } from "@/components/GlassCard";
import { useTreasuryData } from "@/hooks/useTreasuryData";
import { formatNumber, formatSOL } from "@/lib/formatters";

export function TreasuryCard() {
    const { data, isLoading } = useTreasuryData();

    return (
        <GlassCard title="Treasury Vault">
            {isLoading ? (
                <div className="h-24 animate-pulse rounded-lg bg-white/5" />
            ) : (
                <div className="space-y-3">
                    <p className="text-3xl font-bold text-white">
                        {formatSOL(data?.balance ? data.balance * 1e9 : 0)}
                    </p>
                    <div className="flex items-center gap-4 text-xs text-white/40">
                        <span>Signers: {data?.signers.length ?? 0}</span>
                        <span>Threshold: {data?.threshold ?? 0}</span>
                    </div>
                    <div className="flex items-center gap-4 text-xs text-white/40">
                        <span>Daily Cap: {formatNumber(data?.dailySpendCap ?? 0)}</span>
                        <span>Proposals: {data?.proposals.length ?? 0}</span>
                    </div>
                </div>
            )}
        </GlassCard>
    );
}
