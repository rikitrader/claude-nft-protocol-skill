import React from "react";
import { DistributionChart } from "./DistributionChart";
import { TOTAL_SUPPLY, TICKER } from "@/lib/constants";
import { formatNumber } from "@/lib/formatters";

export function TokenomicsSection() {
    return (
        <section className="py-16">
            <h2 className="mb-2 text-center text-sm font-medium uppercase tracking-widest text-white/40">
                Tokenomics
            </h2>
            <p className="mb-8 text-center text-2xl font-bold text-white">
                {formatNumber(TOTAL_SUPPLY)} <span className="text-[#9B59FF]">${TICKER}</span> — Fixed Forever
            </p>
            <div className="mx-auto max-w-xl rounded-2xl border border-white/10 bg-black/40 p-8 backdrop-blur-xl">
                <DistributionChart />
            </div>
        </section>
    );
}
