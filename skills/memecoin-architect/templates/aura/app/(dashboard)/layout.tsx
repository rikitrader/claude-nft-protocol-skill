"use client";

// =============================================================================
// DASHBOARD LAYOUT — Sidebar + Header for holder & admin views
// =============================================================================

import React from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { ConnectButton } from "@/components/wallet/ConnectButton";
import { TICKER } from "@/lib/constants";
import { useRoleGuard } from "@/hooks/useRoleGuard";

const NAV_ITEMS = [
    { label: "Overview", href: "/dashboard", icon: "📊" },
    { label: "Treasury", href: "/dashboard/admin/treasury", icon: "🏛", adminOnly: true },
    { label: "Governance", href: "/dashboard/admin/governance", icon: "🗳", adminOnly: true },
    { label: "Emergency", href: "/dashboard/admin/emergency", icon: "🛡", adminOnly: true },
    { label: "Burns", href: "/dashboard/admin/burns", icon: "🔥", adminOnly: true },
];

export default function DashboardLayout({
    children,
}: {
    children: React.ReactNode;
}) {
    const pathname = usePathname();
    const { isAdmin } = useRoleGuard();

    const visibleNav = NAV_ITEMS.filter((item) => !item.adminOnly || isAdmin);

    return (
        <div className="flex min-h-screen">
            {/* Sidebar */}
            <aside className="hidden w-56 shrink-0 border-r border-white/5 bg-[#0A0A0F]/60 backdrop-blur-lg md:block">
                <div className="flex h-14 items-center border-b border-white/5 px-5">
                    <Link href="/" className="text-lg font-bold text-white">
                        {TICKER}<span className="text-[#00F0FF]">.</span>
                    </Link>
                </div>
                <nav className="mt-4 space-y-1 px-3">
                    {visibleNav.map((item) => {
                        const active = pathname === item.href;
                        return (
                            <Link
                                key={item.href}
                                href={item.href}
                                className={`flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors ${
                                    active
                                        ? "bg-white/10 text-white"
                                        : "text-white/50 hover:bg-white/5 hover:text-white/80"
                                }`}
                            >
                                <span className="text-base">{item.icon}</span>
                                {item.label}
                            </Link>
                        );
                    })}
                </nav>
            </aside>

            {/* Main content */}
            <div className="flex flex-1 flex-col">
                <header className="flex h-14 items-center justify-between border-b border-white/5 bg-[#0A0A0F]/60 px-6 backdrop-blur-lg">
                    <h2 className="text-sm font-medium text-white/60">Dashboard</h2>
                    <ConnectButton />
                </header>
                <main className="flex-1 overflow-y-auto p-6">
                    {children}
                </main>
            </div>
        </div>
    );
}
