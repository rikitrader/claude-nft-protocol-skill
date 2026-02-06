"use client";

import React from "react";
import { motion } from "framer-motion";

interface FeatureCardProps {
    title: string;
    description: string;
    icon: string;
    glowColor?: string;
}

export function FeatureCard({ title, description, icon, glowColor = "var(--aura-cyan)" }: FeatureCardProps) {
    return (
        <motion.div
            whileHover={{ scale: 1.02, y: -4 }}
            className="group relative overflow-hidden rounded-2xl border border-white/10 bg-black/40 p-6 backdrop-blur-xl transition-colors hover:border-white/20"
        >
            <div
                className="absolute -top-12 -right-12 h-32 w-32 rounded-full opacity-10 blur-3xl transition-opacity group-hover:opacity-20"
                style={{ background: glowColor }}
            />
            <div className="relative z-10">
                <span className="mb-3 block text-2xl">{icon}</span>
                <h3 className="mb-2 text-base font-bold text-white">{title}</h3>
                <p className="text-sm leading-relaxed text-white/50">{description}</p>
            </div>
        </motion.div>
    );
}
