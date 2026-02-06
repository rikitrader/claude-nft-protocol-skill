import React from "react";

interface SecurityBadgeProps {
    label: string;
    verified: boolean;
    icon: string;
}

export function SecurityBadge({ label, verified, icon }: SecurityBadgeProps) {
    return (
        <div className="flex items-center gap-3 rounded-xl border border-white/10 bg-white/5 px-4 py-3">
            <span className="text-lg">{icon}</span>
            <span className="text-sm font-medium text-white/80">{label}</span>
            <span
                className={`ml-auto rounded-full px-2 py-0.5 text-[10px] font-bold ${
                    verified
                        ? "bg-emerald-500/20 text-emerald-400"
                        : "bg-amber-500/20 text-amber-400"
                }`}
            >
                {verified ? "VERIFIED" : "PENDING"}
            </span>
        </div>
    );
}
