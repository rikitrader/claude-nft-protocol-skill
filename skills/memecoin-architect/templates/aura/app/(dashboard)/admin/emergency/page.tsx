"use client";

// =============================================================================
// ADMIN: EMERGENCY — Pause/resume controls
// =============================================================================

import React from "react";
import { AdminCard } from "@/components/admin/AdminCard";
import { EmergencyControls } from "@/components/admin/EmergencyControls";

export default function AdminEmergencyPage() {
    return (
        <div className="space-y-6">
            <AdminCard title="Emergency Controls">
                <EmergencyControls />
            </AdminCard>
        </div>
    );
}
