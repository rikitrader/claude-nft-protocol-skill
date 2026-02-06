// =============================================================================
// ROOT LAYOUT — Next.js 15 App Router
// =============================================================================
// Wraps all pages with: fonts, wallet provider, global styles, nav header.
// =============================================================================

import type { Metadata } from "next";
import { Space_Grotesk, Inter } from "next/font/google";
import { WalletProvider } from "@/components/wallet/WalletProvider";
import { QueryProvider } from "@/components/QueryProvider";
import { TICKER } from "@/lib/constants";
import "./globals.css";

const spaceGrotesk = Space_Grotesk({
    subsets: ["latin"],
    variable: "--font-heading",
    display: "swap",
});

const inter = Inter({
    subsets: ["latin"],
    variable: "--font-body",
    display: "swap",
});

export const metadata: Metadata = {
    title: `${TICKER} Dashboard`,
    description: "Real-time on-chain metrics for the memecoin protocol.",
};

export default function RootLayout({
    children,
}: {
    children: React.ReactNode;
}) {
    return (
        <html lang="en" className={`${spaceGrotesk.variable} ${inter.variable}`}>
            <body className="min-h-screen">
                <WalletProvider>
                    <QueryProvider>
                        {children}
                    </QueryProvider>
                </WalletProvider>
            </body>
        </html>
    );
}
