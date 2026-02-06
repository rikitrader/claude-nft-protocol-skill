"use client";

// =============================================================================
// CONNECT BUTTON — Styled Wallet Connect
// =============================================================================
// Glassmorphic connect button using the Aura design tokens.
// Shows truncated address when connected, "Connect Wallet" when not.
// =============================================================================

import React from "react";
import { useWalletModal } from "@solana/wallet-adapter-react-ui";
import { useWallet } from "@solana/wallet-adapter-react";

function truncateAddress(address: string): string {
    return `${address.slice(0, 4)}...${address.slice(-4)}`;
}

export function ConnectButton() {
    const { publicKey, disconnect, connected } = useWallet();
    const { setVisible } = useWalletModal();

    if (connected && publicKey) {
        return (
            <button
                onClick={() => disconnect()}
                className="group flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-sm font-medium text-white/80 backdrop-blur-md transition-all hover:border-white/20 hover:bg-white/10 hover:text-white"
            >
                <span className="h-2 w-2 rounded-full bg-emerald-400" />
                {truncateAddress(publicKey.toBase58())}
            </button>
        );
    }

    return (
        <button
            onClick={() => setVisible(true)}
            className="rounded-xl border border-[#00F0FF]/30 bg-[#00F0FF]/10 px-4 py-2 text-sm font-medium text-[#00F0FF] backdrop-blur-md transition-all hover:border-[#00F0FF]/50 hover:bg-[#00F0FF]/20 hover:shadow-[0_0_20px_rgba(0,240,255,0.15)]"
        >
            Connect Wallet
        </button>
    );
}
