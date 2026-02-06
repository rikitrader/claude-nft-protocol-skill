"use client";

import React from "react";
import { useTreasuryData } from "@/hooks/useTreasuryData";
import { ProposalCard } from "./ProposalCard";

export function ProposalList() {
    const { data, isLoading } = useTreasuryData();

    if (isLoading) {
        return (
            <div className="space-y-2">
                {[1, 2, 3].map((i) => (
                    <div key={i} className="h-16 animate-pulse rounded-xl bg-white/5" />
                ))}
            </div>
        );
    }

    const proposals = data?.proposals ?? [];

    if (proposals.length === 0) {
        return (
            <p className="py-8 text-center text-sm text-white/30">No proposals yet.</p>
        );
    }

    return (
        <div className="space-y-2">
            {proposals.map((p, i) => (
                <ProposalCard
                    key={`${p.recipient}-${p.createdAt}`}
                    proposal={p}
                    threshold={data?.threshold ?? 1}
                    index={i}
                />
            ))}
        </div>
    );
}
