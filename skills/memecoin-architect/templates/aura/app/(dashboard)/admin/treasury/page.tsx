"use client";

// =============================================================================
// ADMIN: TREASURY — Proposal management + treasury overview
// =============================================================================

import React from "react";
import { AdminCard } from "@/components/admin/AdminCard";
import { ProposalList } from "@/components/admin/ProposalList";
import { CreateProposalForm } from "@/components/admin/CreateProposalForm";
import { useTreasuryData } from "@/hooks/useTreasuryData";
import { formatSOL, formatNumber } from "@/lib/formatters";

export default function AdminTreasuryPage() {
    const { data: treasury } = useTreasuryData();

    return (
        <div className="space-y-6">
            {/* Treasury stats */}
            <div className="grid gap-4 sm:grid-cols-3">
                <AdminCard title="Balance">
                    <p className="text-2xl font-bold text-white">
                        {formatSOL(treasury?.balance ? treasury.balance * 1e9 : 0)}
                    </p>
                </AdminCard>
                <AdminCard title="Daily Spend Cap">
                    <p className="text-2xl font-bold text-white">
                        {formatNumber(treasury?.dailySpendCap ?? 0)}
                    </p>
                </AdminCard>
                <AdminCard title="Threshold">
                    <p className="text-2xl font-bold text-white">
                        {treasury?.threshold ?? 0}/{treasury?.signers.length ?? 0}
                    </p>
                    <p className="text-xs text-white/40">signatures required</p>
                </AdminCard>
            </div>

            {/* Proposals */}
            <AdminCard title="Proposals">
                <ProposalList />
            </AdminCard>

            {/* Create proposal */}
            <AdminCard title="New Proposal">
                <CreateProposalForm />
            </AdminCard>
        </div>
    );
}
