"use client";

import React from "react";
import { motion } from "framer-motion";
import { TICKER } from "@/lib/constants";
import { usePriceData } from "@/hooks/usePriceData";
import { formatPercent } from "@/lib/formatters";

export function HeroSection() {
    const { data: price } = usePriceData();

    return (
        <section className="relative flex min-h-[70vh] flex-col items-center justify-center overflow-hidden px-4 text-center">
            {/* Animated gradient orbs */}
            <div className="pointer-events-none absolute inset-0">
                <div className="absolute left-1/4 top-1/4 h-96 w-96 animate-pulse rounded-full bg-[#00F0FF]/10 blur-[120px]" />
                <div className="absolute bottom-1/4 right-1/4 h-96 w-96 animate-pulse rounded-full bg-[#9B59FF]/10 blur-[120px]" style={{ animationDelay: "1s" }} />
                <div className="absolute left-1/2 top-1/2 h-64 w-64 -translate-x-1/2 -translate-y-1/2 animate-pulse rounded-full bg-[#FF6B35]/8 blur-[100px]" style={{ animationDelay: "2s" }} />
            </div>

            <motion.div
                initial={{ opacity: 0, y: 30 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.8 }}
                className="relative z-10"
            >
                <p className="mb-4 text-sm font-medium uppercase tracking-[0.3em] text-[#00F0FF]">
                    The Anti-Rug Protocol
                </p>
                <h1 className="mb-6 text-5xl font-bold leading-tight tracking-tight text-white sm:text-7xl">
                    ${TICKER}
                </h1>
                <p className="mx-auto mb-8 max-w-lg text-lg text-white/50">
                    Fixed supply. Deterministic burns. DAO-governed treasury.
                    Built for transparency — not hype.
                </p>

                {/* Live price ticker */}
                {price && price.price > 0 && (
                    <div className="mb-8 inline-flex items-center gap-3 rounded-full border border-white/10 bg-white/5 px-5 py-2 backdrop-blur-lg">
                        <span className="text-lg font-bold text-white">
                            ${price.price < 0.001 ? price.price.toExponential(4) : price.price.toFixed(6)}
                        </span>
                        <span className={`text-sm font-bold ${price.change24h >= 0 ? "text-emerald-400" : "text-rose-400"}`}>
                            {formatPercent(price.change24h)}
                        </span>
                    </div>
                )}

                {/* CTA buttons */}
                <div className="flex flex-col items-center gap-4 sm:flex-row sm:justify-center">
                    <a
                        href="#buy"
                        className="rounded-xl bg-gradient-to-r from-[#00F0FF] to-[#9B59FF] px-8 py-3 text-sm font-bold text-black transition-transform hover:scale-105"
                    >
                        Buy ${TICKER}
                    </a>
                    <a
                        href="/dashboard"
                        className="rounded-xl border border-white/20 px-8 py-3 text-sm font-bold text-white transition-colors hover:border-white/40 hover:bg-white/5"
                    >
                        Launch Dashboard
                    </a>
                </div>
            </motion.div>
        </section>
    );
}
