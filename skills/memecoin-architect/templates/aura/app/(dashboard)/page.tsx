"use client";

// =============================================================================
// HOLDER DASHBOARD — Live on-chain metrics bento grid
// =============================================================================
// Replaces hardcoded demo values with TanStack Query hooks fetching
// from Anchor PDAs (token_mint, burn_controller, treasury_vault, etc.)
// =============================================================================

import React from "react";
import { GlassCard } from "@/components/GlassCard";
import { BurnMeter } from "@/components/BurnMeter";
import { PriceCard } from "@/components/PriceCard";
import { TreasuryCard } from "@/components/dashboard/TreasuryCard";
import { PriceChart } from "@/components/dashboard/PriceChart";
import { HolderMap } from "@/components/dashboard/HolderMap";
import { LPStatus } from "@/components/dashboard/LPStatus";
import { SupplyTicker } from "@/components/dashboard/SupplyTicker";
import { useTokenMetrics } from "@/hooks/useTokenMetrics";
import { usePriceData } from "@/hooks/usePriceData";
import { useEmergencyStatus } from "@/hooks/useEmergencyStatus";
import { TOTAL_SUPPLY, TICKER } from "@/lib/constants";

export default function DashboardPage() {
    const { data: metrics } = useTokenMetrics();
    const { data: price } = usePriceData();
    const { data: emergency } = useEmergencyStatus();

    return (
        <div className="bento-grid">
            {/* Burn Meter */}
            <GlassCard title="Burn Progress">
                <BurnMeter
                    totalBurned={metrics?.totalBurned ?? 0}
                    totalSupply={metrics?.totalSupply ?? TOTAL_SUPPLY}
                    ticker={TICKER}
                />
            </GlassCard>

            {/* Price Chart (spans 2 columns) */}
            <PriceChart />

            {/* Price summary */}
            <GlassCard title={`${TICKER} Price`}>
                <PriceCard
                    price={price?.price ?? 0}
                    change24h={price?.change24h ?? 0}
                    symbol={TICKER}
                />
            </GlassCard>

            {/* Treasury */}
            <TreasuryCard />

            {/* Top Holders */}
            <HolderMap />

            {/* LP Status */}
            <LPStatus />

            {/* Supply Ticker */}
            <SupplyTicker />

            {/* System Status (full width) */}
            <GlassCard title="System Status" className="col-span-full">
                <div className="flex items-center gap-3">
                    <span className="relative flex h-3 w-3">
                        <span
                            className={`absolute inline-flex h-full w-full animate-ping rounded-full opacity-75 ${
                                emergency?.isPaused ? "bg-rose-400" : "bg-emerald-400"
                            }`}
                        />
                        <span
                            className={`relative inline-flex h-3 w-3 rounded-full ${
                                emergency?.isPaused ? "bg-rose-500" : "bg-emerald-500"
                            }`}
                        />
                    </span>
                    <span
                        className={`text-sm font-medium ${
                            emergency?.isPaused ? "text-rose-400" : "text-emerald-400"
                        }`}
                    >
                        {emergency?.isPaused ? "SYSTEM PAUSED" : "All systems operational"}
                    </span>
                    <span className="ml-auto text-xs text-white/30">
                        Emergency pause: {emergency?.isPaused ? "ON" : "OFF"}
                    </span>
                </div>
            </GlassCard>
        </div>
    );
}
