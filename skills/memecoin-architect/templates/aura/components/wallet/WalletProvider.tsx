"use client";

// =============================================================================
// WALLET PROVIDER — Solana Wallet Adapter Wrapper
// =============================================================================
// Wraps the app with ConnectionProvider + WalletProvider from
// @solana/wallet-adapter-react. Configures supported wallets,
// network endpoint, and auto-connect behavior.
//
// Supported wallets: Phantom, Solflare, Backpack, WalletConnect
// =============================================================================

import React, { useMemo } from "react";
import {
    ConnectionProvider,
    WalletProvider as SolanaWalletProvider,
} from "@solana/wallet-adapter-react";
import { WalletModalProvider } from "@solana/wallet-adapter-react-ui";
import { PhantomWalletAdapter } from "@solana/wallet-adapter-phantom";
import { SolflareWalletAdapter } from "@solana/wallet-adapter-solflare";
import { RPC_ENDPOINT } from "@/lib/constants";

// Import wallet adapter base styles
import "@solana/wallet-adapter-react-ui/styles.css";

interface Props {
    children: React.ReactNode;
}

export function WalletProvider({ children }: Props) {
    const wallets = useMemo(
        () => [
            new PhantomWalletAdapter(),
            new SolflareWalletAdapter(),
        ],
        [],
    );

    return (
        <ConnectionProvider endpoint={RPC_ENDPOINT}>
            <SolanaWalletProvider wallets={wallets} autoConnect>
                <WalletModalProvider>
                    {children}
                </WalletModalProvider>
            </SolanaWalletProvider>
        </ConnectionProvider>
    );
}
