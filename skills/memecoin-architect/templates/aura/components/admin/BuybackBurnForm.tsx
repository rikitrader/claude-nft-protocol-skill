"use client";

import React, { useState, useMemo } from "react";
import { SystemProgram, type TransactionInstruction } from "@solana/web3.js";
import { useTokenMetrics } from "@/hooks/useTokenMetrics";
import { formatNumber } from "@/lib/formatters";
import { TICKER } from "@/lib/constants";
import { TransactionButton } from "./TransactionButton";

export function BuybackBurnForm() {
    const { data: metrics } = useTokenMetrics();
    const [amount, setAmount] = useState("");

    // Placeholder instruction — replace with Anchor treasury_buyback_burn
    const instructions = useMemo((): TransactionInstruction[] => {
        const parsed = parseFloat(amount);
        if (isNaN(parsed) || parsed <= 0) return [];
        return [SystemProgram.transfer({ fromPubkey: SystemProgram.programId, toPubkey: SystemProgram.programId, lamports: 0 })];
    }, [amount]);

    return (
        <div className="space-y-6">
            {/* Current burn stats */}
            <div className="grid gap-4 sm:grid-cols-3">
                <div className="rounded-lg border border-white/5 bg-white/5 p-4">
                    <p className="text-xs text-white/40">Total Burned</p>
                    <p className="text-xl font-bold text-[#FF6B35]">
                        {formatNumber(metrics?.totalBurned ?? 0)} {TICKER}
                    </p>
                </div>
                <div className="rounded-lg border border-white/5 bg-white/5 p-4">
                    <p className="text-xs text-white/40">Burn %</p>
                    <p className="text-xl font-bold text-[#9B59FF]">
                        {(metrics?.burnPercent ?? 0).toFixed(2)}%
                    </p>
                </div>
                <div className="rounded-lg border border-white/5 bg-white/5 p-4">
                    <p className="text-xs text-white/40">Milestones Reached</p>
                    <p className="text-xl font-bold text-white">
                        {metrics?.milestonesReached ?? 0}
                    </p>
                </div>
            </div>

            {/* Trade burn rate */}
            <div className="rounded-lg border border-white/5 bg-white/5 p-4">
                <p className="text-xs text-white/40">Active Trade Burn Rate</p>
                <p className="text-lg font-bold text-white">
                    {metrics?.tradeBurnBps ?? 0} bps
                    <span className="ml-2 text-sm text-white/40">
                        ({((metrics?.tradeBurnBps ?? 0) / 100).toFixed(2)}% per trade)
                    </span>
                </p>
                <p className="mt-1 text-xs text-white/30">
                    Status: {metrics?.burnPaused ? "PAUSED" : "ACTIVE"}
                </p>
            </div>

            {/* Buyback + burn form */}
            <div>
                <label className="mb-1 block text-xs text-white/40">
                    Buyback Amount ({TICKER})
                </label>
                <input
                    type="number"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    placeholder="Amount to buy back and burn..."
                    step="1000"
                    min="0"
                    className="w-full rounded-lg border border-white/10 bg-white/5 px-4 py-2.5 text-sm text-white placeholder-white/20 outline-none focus:border-[#FF6B35]/40"
                />
            </div>
            <TransactionButton
                label={`Buyback & Burn ${amount || "0"} ${TICKER}`}
                instructions={instructions}
                onSuccess={() => setAmount("")}
                className="bg-gradient-to-r from-[#FF6B35] to-[#9B59FF]"
            />
        </div>
    );
}
