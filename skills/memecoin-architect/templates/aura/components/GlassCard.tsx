"use client";

import React from 'react';
import { motion } from 'framer-motion';

/**
 * GLASS CARD COMPONENT
 * 
 * A reusable glassmorphic container with backdrop blur, subtle borders, 
 * and a dark gradient background. Foundation of the Aura Design System.
 */

interface GlassCardProps {
    children: React.ReactNode;
    title?: string;
    className?: string;
}

export const GlassCard: React.FC<GlassCardProps> = ({ children, title, className = "" }) => {
    return (
        <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
            className={`relative overflow-hidden rounded-2xl border border-white/10 bg-black/40 p-6 backdrop-blur-xl ${className}`}
        >
            {/* Glossy Overlay */}
            <div className="absolute inset-0 bg-gradient-to-br from-white/5 to-transparent pointer-events-none" />

            {title && (
                <h3 className="mb-4 text-sm font-medium uppercase tracking-wider text-white/60">
                    {title}
                </h3>
            )}

            <div className="relative z-10">
                {children}
            </div>
        </motion.div>
    );
};
