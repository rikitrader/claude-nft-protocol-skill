"use client";

import React from "react";
import { GlassCard } from "@/components/GlassCard";

// LP status is read from on-chain lock data — placeholder values shown
// Replace with actual LP lock contract read when available

export function LPStatus() {
    const isLocked = true;
    const lockDaysRemaining = 180;
    const tvl = 450_000;

    return (
        <GlassCard title="Liquidity Pool">
            <div className="space-y-3">
                <div className="flex items-center gap-2">
                    <span className={`h-2 w-2 rounded-full ${isLocked ? "bg-emerald-400" : "bg-rose-400"}`} />
                    <span className={`text-sm font-medium ${isLocked ? "text-emerald-400" : "text-rose-400"}`}>
                        {isLocked ? "LOCKED" : "UNLOCKED"}
                    </span>
                </div>
                <p className="text-2xl font-bold text-white">
                    ${tvl.toLocaleString()}
                </p>
                <p className="text-xs text-white/40">
                    Lock expires in {lockDaysRemaining} days
                </p>
                {/* LP depth bar */}
                <div className="h-1.5 w-full overflow-hidden rounded-full bg-white/5">
                    <div
                        className="h-full rounded-full bg-gradient-to-r from-[#00F0FF] to-[#9B59FF]"
                        style={{ width: `${Math.min(100, (lockDaysRemaining / 365) * 100)}%` }}
                    />
                </div>
            </div>
        </GlassCard>
    );
}
