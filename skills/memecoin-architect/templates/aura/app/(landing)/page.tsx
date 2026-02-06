"use client";

// =============================================================================
// LANDING PAGE — Crypto-native dark glassmorphic marketing page
// =============================================================================

import React from "react";
import { HeroSection } from "@/components/landing/HeroSection";
import { FeatureGrid } from "@/components/landing/FeatureGrid";
import { TokenomicsSection } from "@/components/landing/TokenomicsSection";
import { SecurityBadges } from "@/components/landing/SecurityBadges";
import { CTASection } from "@/components/landing/CTASection";
import { Footer } from "@/components/landing/Footer";

export default function LandingPage() {
    return (
        <>
            <HeroSection />

            <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
                {/* Features */}
                <section className="py-16">
                    <h2 className="mb-2 text-center text-sm font-medium uppercase tracking-widest text-white/40">
                        Architecture
                    </h2>
                    <p className="mb-8 text-center text-2xl font-bold text-white">
                        Built Different. <span className="text-[#00F0FF]">Verified On-Chain.</span>
                    </p>
                    <FeatureGrid />
                </section>

                <TokenomicsSection />
                <SecurityBadges />
                <CTASection />
            </div>

            <Footer />
        </>
    );
}
