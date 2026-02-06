"use client";

// =============================================================================
// ADMIN OVERVIEW — System status summary
// =============================================================================

import React from "react";
import { AdminCard } from "@/components/admin/AdminCard";
import { useTokenMetrics } from "@/hooks/useTokenMetrics";
import { useTreasuryData } from "@/hooks/useTreasuryData";
import { useGovernanceData } from "@/hooks/useGovernanceData";
import { useEmergencyStatus } from "@/hooks/useEmergencyStatus";
import { useRoleGuard } from "@/hooks/useRoleGuard";
import { formatNumber, formatSOL, shortenAddress } from "@/lib/formatters";

export default function AdminOverviewPage() {
    const { data: metrics } = useTokenMetrics();
    const { data: treasury } = useTreasuryData();
    const { data: governance } = useGovernanceData();
    const { data: emergency } = useEmergencyStatus();
    const { isSigner, isGuardian, walletAddress } = useRoleGuard();

    return (
        <div className="space-y-6">
            {/* Role banner */}
            <div className="rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm">
                <span className="text-white/40">Signed in as </span>
                <span className="font-mono text-white">{shortenAddress(walletAddress ?? "")}</span>
                <span className="text-white/40"> — </span>
                {isSigner && <span className="text-[#00F0FF]">Treasury Signer</span>}
                {isSigner && isGuardian && <span className="text-white/40"> + </span>}
                {isGuardian && <span className="text-[#9B59FF]">Emergency Guardian</span>}
            </div>

            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                {/* System status */}
                <AdminCard title="System">
                    <div className="flex items-center gap-2">
                        <span className={`h-2.5 w-2.5 rounded-full ${emergency?.isPaused ? "bg-rose-500" : "bg-emerald-500"}`} />
                        <span className={`text-sm font-bold ${emergency?.isPaused ? "text-rose-400" : "text-emerald-400"}`}>
                            {emergency?.isPaused ? "PAUSED" : "OPERATIONAL"}
                        </span>
                    </div>
                </AdminCard>

                {/* Treasury balance */}
                <AdminCard title="Treasury">
                    <p className="text-lg font-bold text-white">
                        {formatSOL(treasury?.balance ? treasury.balance * 1e9 : 0)}
                    </p>
                </AdminCard>

                {/* Pending proposals */}
                <AdminCard title="Proposals">
                    <p className="text-lg font-bold text-white">
                        {treasury?.proposals.filter((p) => !p.executed).length ?? 0}
                        <span className="ml-1 text-sm text-white/40">pending</span>
                    </p>
                </AdminCard>

                {/* Burn rate */}
                <AdminCard title="Burn Rate">
                    <p className="text-lg font-bold text-[#FF6B35]">
                        {metrics?.tradeBurnBps ?? 0} bps
                    </p>
                    <p className="text-xs text-white/40">
                        Total burned: {formatNumber(metrics?.totalBurned ?? 0)}
                    </p>
                </AdminCard>
            </div>

            {/* Governance summary */}
            <AdminCard title="Governance Config">
                <div className="grid gap-4 sm:grid-cols-3">
                    <div>
                        <p className="text-xs text-white/40">Owners</p>
                        <p className="text-sm font-bold text-white">{governance?.owners.length ?? 0}</p>
                    </div>
                    <div>
                        <p className="text-xs text-white/40">Threshold</p>
                        <p className="text-sm font-bold text-white">
                            {governance?.threshold ?? 0}/{governance?.owners.length ?? 0}
                        </p>
                    </div>
                    <div>
                        <p className="text-xs text-white/40">Spend Cap / Tx</p>
                        <p className="text-sm font-bold text-white">
                            {formatSOL((governance?.spendCapPerTx ?? 0) * 1e9)}
                        </p>
                    </div>
                </div>
            </AdminCard>
        </div>
    );
}
