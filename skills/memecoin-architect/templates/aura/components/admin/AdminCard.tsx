"use client";

import React from "react";
import { motion } from "framer-motion";

interface AdminCardProps {
    children: React.ReactNode;
    title: string;
    action?: React.ReactNode;
    className?: string;
}

export function AdminCard({ children, title, action, className = "" }: AdminCardProps) {
    return (
        <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            className={`rounded-2xl border border-white/10 bg-black/40 p-6 backdrop-blur-xl ${className}`}
        >
            <div className="mb-4 flex items-center justify-between">
                <h3 className="text-sm font-medium uppercase tracking-wider text-white/60">{title}</h3>
                {action}
            </div>
            {children}
        </motion.div>
    );
}
