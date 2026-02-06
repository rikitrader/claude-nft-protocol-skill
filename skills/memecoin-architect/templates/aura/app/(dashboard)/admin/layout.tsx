"use client";

// =============================================================================
// ADMIN LAYOUT — Wallet-gated with RoleGuard
// =============================================================================

import React from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { RoleGuard } from "@/components/admin/RoleGuard";

const ADMIN_TABS = [
    { label: "Overview", href: "/dashboard/admin" },
    { label: "Treasury", href: "/dashboard/admin/treasury" },
    { label: "Governance", href: "/dashboard/admin/governance" },
    { label: "Emergency", href: "/dashboard/admin/emergency" },
    { label: "Burns", href: "/dashboard/admin/burns" },
];

export default function AdminLayout({
    children,
}: {
    children: React.ReactNode;
}) {
    const pathname = usePathname();

    return (
        <RoleGuard>
            <div>
                {/* Admin tabs */}
                <div className="mb-6 flex gap-1 overflow-x-auto rounded-xl border border-white/5 bg-white/5 p-1">
                    {ADMIN_TABS.map((tab) => {
                        const active = pathname === tab.href;
                        return (
                            <Link
                                key={tab.href}
                                href={tab.href}
                                className={`whitespace-nowrap rounded-lg px-4 py-2 text-sm font-medium transition-colors ${
                                    active
                                        ? "bg-white/10 text-white"
                                        : "text-white/40 hover:text-white/70"
                                }`}
                            >
                                {tab.label}
                            </Link>
                        );
                    })}
                </div>
                {children}
            </div>
        </RoleGuard>
    );
}
