"use client";

import React from "react";
import { GlassCard } from "@/components/GlassCard";
import { useTokenMetrics } from "@/hooks/useTokenMetrics";
import { formatNumber } from "@/lib/formatters";
import { TICKER } from "@/lib/constants";

export function SupplyTicker() {
    const { data, isLoading } = useTokenMetrics();

    return (
        <GlassCard title="Supply">
            {isLoading ? (
                <div className="h-20 animate-pulse rounded-lg bg-white/5" />
            ) : (
                <div className="space-y-3">
                    <div>
                        <p className="text-xs text-white/40">Circulating</p>
                        <p className="text-2xl font-bold text-white">
                            {formatNumber(data?.circulatingSupply ?? 0)}
                        </p>
                    </div>
                    <div className="flex gap-4">
                        <div>
                            <p className="text-xs text-white/40">Burned</p>
                            <p className="text-sm font-bold text-[#FF6B35]">
                                {formatNumber(data?.totalBurned ?? 0)} {TICKER}
                            </p>
                        </div>
                        <div>
                            <p className="text-xs text-white/40">Burn %</p>
                            <p className="text-sm font-bold text-[#9B59FF]">
                                {(data?.burnPercent ?? 0).toFixed(2)}%
                            </p>
                        </div>
                    </div>
                </div>
            )}
        </GlassCard>
    );
}
