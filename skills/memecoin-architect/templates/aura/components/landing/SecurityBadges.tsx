import React from "react";
import { SecurityBadge } from "./SecurityBadge";

const BADGES = [
    { label: "Mint Authority Revoked", verified: true, icon: "🔒" },
    { label: "LP Tokens Locked", verified: true, icon: "🔐" },
    { label: "Multi-Sig Treasury", verified: true, icon: "🏛" },
    { label: "Emergency Pause System", verified: true, icon: "🛡" },
];

export function SecurityBadges() {
    return (
        <section className="py-16">
            <h2 className="mb-2 text-center text-sm font-medium uppercase tracking-widest text-white/40">
                Security Verification
            </h2>
            <p className="mb-8 text-center text-2xl font-bold text-white">
                Trust, <span className="text-[#00F0FF]">Verified On-Chain</span>
            </p>
            <div className="mx-auto grid max-w-2xl gap-3">
                {BADGES.map((b) => (
                    <SecurityBadge key={b.label} {...b} />
                ))}
            </div>
        </section>
    );
}
