import React from "react";
import { TICKER } from "@/lib/constants";
import { SocialLinks } from "./SocialLinks";

export function Footer() {
    return (
        <footer className="border-t border-white/5 px-6 py-12">
            <div className="mx-auto flex max-w-6xl flex-col items-center gap-6 sm:flex-row sm:justify-between">
                <div>
                    <span className="text-lg font-bold text-white">
                        ${TICKER}
                    </span>
                    <p className="mt-1 max-w-xs text-xs text-white/30">
                        This token is a community experiment. Not financial advice.
                        No guaranteed returns. DYOR.
                    </p>
                </div>
                <SocialLinks />
            </div>
        </footer>
    );
}
