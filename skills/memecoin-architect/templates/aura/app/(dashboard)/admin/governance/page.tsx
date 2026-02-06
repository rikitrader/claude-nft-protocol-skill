"use client";

// =============================================================================
// ADMIN: GOVERNANCE — Multi-sig config management
// =============================================================================

import React from "react";
import { AdminCard } from "@/components/admin/AdminCard";
import { GovernanceConfigPanel } from "@/components/admin/GovernanceConfigPanel";

export default function AdminGovernancePage() {
    return (
        <div className="space-y-6">
            <AdminCard title="Governance Configuration">
                <GovernanceConfigPanel />
            </AdminCard>
        </div>
    );
}
