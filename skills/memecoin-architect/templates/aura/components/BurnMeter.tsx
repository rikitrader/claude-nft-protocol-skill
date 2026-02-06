"use client";

import React from 'react';
import { motion } from 'framer-motion';

/**
 * BURN METER COMPONENT
 * 
 * Visualizes token burn progress using a semi-circular or circular progress ring.
 * Uses Framer Motion for smooth transitions between supply states.
 */

interface BurnMeterProps {
    totalBurned: number;
    totalSupply: number;
    ticker?: string;
}

export const BurnMeter: React.FC<BurnMeterProps> = ({ totalBurned, totalSupply, ticker = "TOKEN" }) => {
    const burnedPercentage = (totalBurned / totalSupply) * 100;
    const radius = 80;
    const circumference = 2 * Math.PI * radius;
    const strokeDashoffset = circumference - (burnedPercentage / 100) * circumference;

    return (
        <div className="flex flex-col items-center justify-center p-4">
            <div className="relative h-48 w-48">
                {/* Background Ring */}
                <svg className="h-full w-full -rotate-90 transform">
                    <circle
                        cx="96"
                        cy="96"
                        r={radius}
                        stroke="currentColor"
                        strokeWidth="12"
                        fill="transparent"
                        className="text-white/5"
                    />
                    {/* Progress Ring */}
                    <motion.circle
                        initial={{ strokeDashoffset: circumference }}
                        animate={{ strokeDashoffset }}
                        transition={{ duration: 1.5, ease: "easeOut" }}
                        cx="96"
                        cy="96"
                        r={radius}
                        stroke="url(#burnGradient)"
                        strokeWidth="12"
                        strokeDasharray={circumference}
                        fill="transparent"
                        strokeLinecap="round"
                    />
                    <defs>
                        <linearGradient id="burnGradient" x1="0%" y1="0%" x2="100%" y2="100%">
                            <stop offset="0%" stopColor="#FF6B35" /> {/* Burn Orange */}
                            <stop offset="100%" stopColor="#9B59FF" /> {/* Phantom Purple */}
                        </linearGradient>
                    </defs>
                </svg>

                {/* Center Text */}
                <div className="absolute inset-0 flex flex-col items-center justify-center">
                    <motion.span
                        initial={{ scale: 0.5 }}
                        animate={{ scale: 1 }}
                        className="text-3xl font-bold text-white"
                    >
                        {burnedPercentage.toFixed(1)}%
                    </motion.span>
                    <span className="text-[10px] uppercase tracking-widest text-white/40">Burned</span>
                </div>
            </div>

            <div className="mt-6 w-full space-y-2 text-center">
                <div className="flex justify-between text-[11px] font-medium uppercase tracking-tighter text-white/60">
                    <span>{totalBurned.toLocaleString()} {ticker}</span>
                    <span>/</span>
                    <span>{totalSupply.toLocaleString()}</span>
                </div>
                <div className="h-1.5 w-full overflow-hidden rounded-full bg-white/5">
                    <motion.div
                        initial={{ width: 0 }}
                        animate={{ width: `${burnedPercentage}%` }}
                        transition={{ duration: 1.5 }}
                        className="h-full bg-gradient-to-r from-[#FF6B35] to-[#9B59FF]"
                    />
                </div>
            </div>
        </div>
    );
};
