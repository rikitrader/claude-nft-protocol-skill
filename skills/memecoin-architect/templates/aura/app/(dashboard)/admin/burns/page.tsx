"use client";

// =============================================================================
// ADMIN: BURNS — Burn metrics + treasury buyback controls
// =============================================================================

import React from "react";
import { AdminCard } from "@/components/admin/AdminCard";
import { BuybackBurnForm } from "@/components/admin/BuybackBurnForm";

export default function AdminBurnsPage() {
    return (
        <div className="space-y-6">
            <AdminCard title="Burn Controls">
                <BuybackBurnForm />
            </AdminCard>
        </div>
    );
}
