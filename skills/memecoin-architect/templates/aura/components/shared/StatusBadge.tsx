import React from "react";

type Status = "active" | "paused" | "locked" | "pending" | "executed";

const STATUS_STYLES: Record<Status, string> = {
    active: "bg-emerald-500/20 text-emerald-400",
    paused: "bg-rose-500/20 text-rose-400",
    locked: "bg-[#00F0FF]/20 text-[#00F0FF]",
    pending: "bg-amber-500/20 text-amber-400",
    executed: "bg-white/10 text-white/40",
};

interface StatusBadgeProps {
    status: Status;
    label?: string;
}

export function StatusBadge({ status, label }: StatusBadgeProps) {
    return (
        <span className={`inline-block rounded-full px-3 py-1 text-[10px] font-bold uppercase ${STATUS_STYLES[status]}`}>
            {label ?? status}
        </span>
    );
}
