// =============================================================================
// LANDING LAYOUT — Minimal chrome for the marketing page
// =============================================================================
// Route group (landing) uses a clean layout without dashboard sidebar/header.
// The root layout (fonts, WalletProvider) still wraps everything.
// =============================================================================

import React from "react";

export default function LandingLayout({
    children,
}: {
    children: React.ReactNode;
}) {
    return (
        <div className="min-h-screen">
            {children}
        </div>
    );
}
