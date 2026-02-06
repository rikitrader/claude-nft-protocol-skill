"use client";

import React from "react";
import { motion } from "framer-motion";
import { TICKER } from "@/lib/constants";

export function CTASection() {
    return (
        <section className="py-20">
            <motion.div
                initial={{ opacity: 0, scale: 0.95 }}
                whileInView={{ opacity: 1, scale: 1 }}
                viewport={{ once: true }}
                className="relative mx-auto max-w-2xl overflow-hidden rounded-3xl border border-white/10 bg-black/40 p-10 text-center backdrop-blur-xl"
            >
                <div className="pointer-events-none absolute inset-0">
                    <div className="absolute -left-20 -top-20 h-64 w-64 rounded-full bg-[#00F0FF]/10 blur-[80px]" />
                    <div className="absolute -bottom-20 -right-20 h-64 w-64 rounded-full bg-[#9B59FF]/10 blur-[80px]" />
                </div>
                <div className="relative z-10">
                    <h2 className="mb-4 text-3xl font-bold text-white">
                        Ready to join ${TICKER}?
                    </h2>
                    <p className="mb-8 text-white/50">
                        Transparent tokenomics. On-chain governance. No rugs.
                    </p>
                    <div className="flex flex-col items-center gap-4 sm:flex-row sm:justify-center">
                        <a
                            href="#buy"
                            className="rounded-xl bg-gradient-to-r from-[#00F0FF] to-[#9B59FF] px-8 py-3 text-sm font-bold text-black transition-transform hover:scale-105"
                        >
                            Buy ${TICKER}
                        </a>
                        <a
                            href="/dashboard"
                            className="rounded-xl border border-white/20 px-8 py-3 text-sm font-bold text-white transition-colors hover:border-white/40"
                        >
                            View Dashboard
                        </a>
                    </div>
                </div>
            </motion.div>
        </section>
    );
}
