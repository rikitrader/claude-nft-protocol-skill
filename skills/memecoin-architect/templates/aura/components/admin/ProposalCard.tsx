"use client";

import React from "react";
import type { Proposal } from "@/hooks/useTreasuryData";
import { shortenAddress, formatSOL, timeAgo } from "@/lib/formatters";

interface ProposalCardProps {
    proposal: Proposal;
    threshold: number;
    index: number;
}

export function ProposalCard({ proposal, threshold, index }: ProposalCardProps) {
    const approvalCount = proposal.approvals.length;
    const isExecuted = proposal.executed;
    const isReady = approvalCount >= threshold && !isExecuted;

    let statusColor = "bg-amber-500/20 text-amber-400";
    let statusText = `${approvalCount}/${threshold} Approved`;
    if (isExecuted) {
        statusColor = "bg-white/10 text-white/40";
        statusText = "Executed";
    } else if (isReady) {
        statusColor = "bg-emerald-500/20 text-emerald-400";
        statusText = "Ready";
    }

    return (
        <div className="flex items-center justify-between rounded-xl border border-white/5 bg-white/5 px-4 py-3">
            <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2">
                    <span className="text-xs text-white/30">#{index + 1}</span>
                    <p className="truncate text-sm font-medium text-white">
                        {proposal.description || `Transfer to ${shortenAddress(proposal.recipient)}`}
                    </p>
                </div>
                <p className="mt-1 text-xs text-white/40">
                    {formatSOL(proposal.amount)} &middot; {timeAgo(proposal.createdAt)}
                </p>
            </div>
            <span className={`shrink-0 rounded-full px-3 py-1 text-[10px] font-bold ${statusColor}`}>
                {statusText}
            </span>
        </div>
    );
}
