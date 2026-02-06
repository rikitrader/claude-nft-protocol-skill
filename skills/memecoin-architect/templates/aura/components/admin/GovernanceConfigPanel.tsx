"use client";

import React from "react";
import { useGovernanceData } from "@/hooks/useGovernanceData";
import { shortenAddress, formatSOL } from "@/lib/formatters";

export function GovernanceConfigPanel() {
    const { data, isLoading } = useGovernanceData();

    if (isLoading) {
        return <div className="h-32 animate-pulse rounded-lg bg-white/5" />;
    }

    return (
        <div className="space-y-6">
            {/* Owners list */}
            <div>
                <h4 className="mb-2 text-xs font-medium uppercase tracking-wider text-white/40">
                    Owners ({data?.owners.length ?? 0})
                </h4>
                <div className="space-y-1">
                    {data?.owners.map((owner) => (
                        <div
                            key={owner}
                            className="flex items-center gap-2 rounded-lg bg-white/5 px-3 py-2 font-mono text-sm text-white/70"
                        >
                            <span className="h-2 w-2 rounded-full bg-[#00F0FF]" />
                            {shortenAddress(owner, 6)}
                        </div>
                    ))}
                </div>
            </div>

            {/* Config values */}
            <div className="grid gap-4 sm:grid-cols-2">
                <div className="rounded-lg border border-white/5 bg-white/5 p-4">
                    <p className="text-xs text-white/40">Approval Threshold</p>
                    <p className="text-xl font-bold text-white">
                        {data?.threshold ?? 0} of {data?.owners.length ?? 0}
                    </p>
                </div>
                <div className="rounded-lg border border-white/5 bg-white/5 p-4">
                    <p className="text-xs text-white/40">Spend Cap / Tx</p>
                    <p className="text-xl font-bold text-white">
                        {formatSOL((data?.spendCapPerTx ?? 0) * 1e9)}
                    </p>
                </div>
            </div>

            {/* Governance proposals */}
            <div>
                <h4 className="mb-2 text-xs font-medium uppercase tracking-wider text-white/40">
                    Config Proposals ({data?.proposals.length ?? 0})
                </h4>
                {data?.proposals.length === 0 ? (
                    <p className="py-4 text-center text-sm text-white/30">No config proposals.</p>
                ) : (
                    <div className="space-y-2">
                        {data?.proposals.map((p, i) => (
                            <div
                                key={`${p.proposer}-${p.createdAt}`}
                                className="flex items-center justify-between rounded-xl border border-white/5 bg-white/5 px-4 py-3"
                            >
                                <div>
                                    <p className="text-sm font-medium text-white">
                                        #{i + 1} {p.proposalType === "transfer" ? "Transfer" : "Config Change"}
                                    </p>
                                    <p className="text-xs text-white/40">
                                        by {shortenAddress(p.proposer)}
                                    </p>
                                </div>
                                <span
                                    className={`rounded-full px-3 py-1 text-[10px] font-bold ${
                                        p.executed
                                            ? "bg-white/10 text-white/40"
                                            : "bg-amber-500/20 text-amber-400"
                                    }`}
                                >
                                    {p.executed ? "Executed" : `${p.approvals.length} approved`}
                                </span>
                            </div>
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
}
