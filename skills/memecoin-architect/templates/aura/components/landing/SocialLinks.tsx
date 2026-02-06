"use client";

import React from "react";

const SOCIALS = [
    { label: "Twitter", href: "#", icon: "𝕏" },
    { label: "Discord", href: "#", icon: "💬" },
    { label: "Telegram", href: "#", icon: "✈" },
    { label: "GitHub", href: "#", icon: "⌥" },
];

export function SocialLinks() {
    return (
        <div className="flex items-center gap-4">
            {SOCIALS.map((s) => (
                <a
                    key={s.label}
                    href={s.href}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex h-10 w-10 items-center justify-center rounded-full border border-white/10 text-sm text-white/60 transition-colors hover:border-[#00F0FF]/40 hover:text-[#00F0FF]"
                    aria-label={s.label}
                >
                    {s.icon}
                </a>
            ))}
        </div>
    );
}
