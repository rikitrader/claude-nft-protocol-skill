"use client";

import React from "react";
import { useRoleGuard } from "@/hooks/useRoleGuard";
import { GlassCard } from "@/components/GlassCard";

interface RoleGuardProps {
    children: React.ReactNode;
}

export function RoleGuard({ children }: RoleGuardProps) {
    const { isConnected, isAdmin } = useRoleGuard();

    if (!isConnected) {
        return (
            <div className="flex min-h-[60vh] items-center justify-center">
                <GlassCard className="max-w-md text-center">
                    <p className="text-lg font-bold text-white">Connect Wallet</p>
                    <p className="mt-2 text-sm text-white/50">
                        Connect your wallet to access the admin dashboard.
                    </p>
                </GlassCard>
            </div>
        );
    }

    if (!isAdmin) {
        return (
            <div className="flex min-h-[60vh] items-center justify-center">
                <GlassCard className="max-w-md text-center">
                    <p className="text-lg font-bold text-rose-400">Access Denied</p>
                    <p className="mt-2 text-sm text-white/50">
                        This area is restricted to treasury signers and emergency guardians.
                    </p>
                </GlassCard>
            </div>
        );
    }

    return <>{children}</>;
}
