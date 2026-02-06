"use client";

// =============================================================================
// DASHBOARD HOME — Bento Grid Layout
// =============================================================================
// Main dashboard page rendering all metric cards in a responsive bento grid.
// Each card is wrapped in GlassCard for consistent glassmorphic styling.
//
// Layout (desktop 1280px+):
//   ┌────────┬────────┬────────┐
//   │  Burn  │ Price  │ Price  │
//   │  Meter │ Chart  │ Chart  │
//   ├────────┼────────┼────────┤
//   │Treasury│ Holders│   LP   │
//   │  Card  │  Map   │ Status │
//   ├────────┼────────┴────────┤
//   │ Supply │   Governance    │
//   │ Ticker │     Panel       │
//   └────────┴─────────────────┘
// =============================================================================

import React from "react";
import { GlassCard } from "@/components/GlassCard";
import { BurnMeter } from "@/components/BurnMeter";
import { PriceCard } from "@/components/PriceCard";
import { TOTAL_SUPPLY, TICKER } from "@/lib/constants";

export default function DashboardPage() {
    // =========================================================================
    // TODO: Replace static values with TanStack Query hooks:
    //   const { data: metrics } = useTokenMetrics();
    //   const { data: price }   = usePriceData();
    //   const { data: paused }  = usePauseStatus();
    // =========================================================================

    return (
        <div className="bento-grid">
            {/* Burn Meter */}
            <GlassCard title="Burn Progress">
                <BurnMeter
                    totalBurned={124_000_000}
                    totalSupply={TOTAL_SUPPLY}
                    ticker={TICKER}
                />
            </GlassCard>

            {/* Price Chart (spans 2 columns on desktop) */}
            <GlassCard title={`${TICKER} / USDC`} className="bento-span-2">
                <PriceCard
                    price={0.00042}
                    change24h={8.2}
                    symbol={TICKER}
                />
                {/* TODO: Replace with <PriceChart /> using Recharts */}
                <div className="mt-4 flex h-48 items-center justify-center rounded-lg border border-dashed border-white/10 text-sm text-white/30">
                    Candlestick chart — integrate Recharts
                </div>
            </GlassCard>

            {/* Treasury */}
            <GlassCard title="Treasury Vault">
                <div className="space-y-3">
                    <p className="text-3xl font-bold text-white">
                        847,234 <span className="text-lg text-white/40">USDC</span>
                    </p>
                    <p className="text-sm text-emerald-400">+12,450 (24h)</p>
                    {/* TODO: Replace with <TreasuryCard /> sparkline */}
                    <div className="h-12 rounded-lg bg-white/5" />
                </div>
            </GlassCard>

            {/* Holder Distribution */}
            <GlassCard title="Top Holders">
                {/* TODO: Replace with <HolderMap /> donut chart */}
                <div className="flex h-48 items-center justify-center text-sm text-white/30">
                    Donut chart — integrate Recharts
                </div>
            </GlassCard>

            {/* LP Status */}
            <GlassCard title="Liquidity Pool">
                <div className="space-y-3">
                    <div className="flex items-center gap-2">
                        <span className="h-2 w-2 rounded-full bg-emerald-400" />
                        <span className="text-sm font-medium text-emerald-400">LOCKED</span>
                    </div>
                    <p className="text-2xl font-bold text-white">$450,000</p>
                    <p className="text-xs text-white/40">Lock expires: 180 days</p>
                    {/* TODO: Replace with <LPStatus /> countdown + depth bar */}
                </div>
            </GlassCard>

            {/* Supply Ticker */}
            <GlassCard title="Circulating Supply">
                <div className="space-y-2">
                    <p className="text-2xl font-bold text-white">
                        876,000,000
                    </p>
                    <p className="text-xs text-white/40">
                        of {TOTAL_SUPPLY.toLocaleString()} total
                    </p>
                    {/* TODO: Replace with <SupplyTicker /> animated counter */}
                </div>
            </GlassCard>

            {/* Governance Panel (spans 2 columns) */}
            <GlassCard title="Governance" className="bento-span-2">
                <div className="space-y-3">
                    <div className="flex items-center justify-between rounded-lg bg-white/5 px-4 py-3">
                        <div>
                            <p className="text-sm font-medium text-white">Proposal #1: Buyback 50K USDC</p>
                            <p className="text-xs text-white/40">Ends in 2 days</p>
                        </div>
                        <span className="rounded-full bg-[#00F0FF]/10 px-3 py-1 text-xs font-bold text-[#00F0FF]">
                            ACTIVE
                        </span>
                    </div>
                    {/* TODO: Replace with <GovernancePanel /> */}
                </div>
            </GlassCard>

            {/* Emergency Status (full width) */}
            <GlassCard title="System Status" className="col-span-full">
                <div className="flex items-center gap-3">
                    <span className="relative flex h-3 w-3">
                        <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-75" />
                        <span className="relative inline-flex h-3 w-3 rounded-full bg-emerald-500" />
                    </span>
                    <span className="text-sm font-medium text-emerald-400">All systems operational</span>
                    <span className="ml-auto text-xs text-white/30">Emergency pause: OFF</span>
                </div>
            </GlassCard>
        </div>
    );
}
