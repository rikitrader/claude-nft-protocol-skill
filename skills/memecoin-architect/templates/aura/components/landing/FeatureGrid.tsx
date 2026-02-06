import React from "react";
import { FeatureCard } from "./FeatureCard";

const FEATURES = [
    { title: "Fixed Supply", description: "One-time mint, no inflation. Mint authority permanently revoked.", icon: "🔒", glow: "var(--aura-cyan)" },
    { title: "Auto-Burns", description: "Deterministic burns on every trade. No manual buttons — pure math.", icon: "🔥", glow: "var(--aura-orange)" },
    { title: "Treasury DAO", description: "Multi-sig treasury with on-chain proposals. Every spend is voted on.", icon: "🏛", glow: "var(--aura-purple)" },
    { title: "LP Locked", description: "Liquidity pool tokens locked 6-12 months. No rug, no withdraw.", icon: "🔐", glow: "var(--aura-cyan)" },
    { title: "Emergency Controls", description: "Time-limited pause for exploits only. Cannot mint, cannot rug.", icon: "🛡", glow: "var(--aura-orange)" },
    { title: "Cross-Chain Ready", description: "Solana as source of truth. Bridge to Base and Ethereum when ready.", icon: "🌐", glow: "var(--aura-purple)" },
];

export function FeatureGrid() {
    return (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {FEATURES.map((f) => (
                <FeatureCard
                    key={f.title}
                    title={f.title}
                    description={f.description}
                    icon={f.icon}
                    glowColor={f.glow}
                />
            ))}
        </div>
    );
}
