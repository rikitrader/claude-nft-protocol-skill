"use client";

// =============================================================================
// useRoleGuard — Wallet-based admin role detection
// =============================================================================
// Checks if the connected wallet is a treasury signer or emergency guardian.
// Used by the admin layout to gate access.
// =============================================================================

import { useMemo } from "react";
import { useWallet } from "@solana/wallet-adapter-react";
import { useTreasuryData } from "./useTreasuryData";
import { useEmergencyStatus } from "./useEmergencyStatus";

export interface RoleInfo {
    isConnected: boolean;
    isSigner: boolean;
    isGuardian: boolean;
    isAdmin: boolean;
    walletAddress: string | null;
}

export function useRoleGuard(): RoleInfo {
    const { publicKey } = useWallet();
    const { data: treasury } = useTreasuryData();
    const { data: emergency } = useEmergencyStatus();

    return useMemo(() => {
        const address = publicKey?.toBase58() ?? null;
        const isSigner = address ? (treasury?.signers.includes(address) ?? false) : false;
        const isGuardian = address ? (emergency?.guardians.includes(address) ?? false) : false;

        return {
            isConnected: !!publicKey,
            isSigner,
            isGuardian,
            isAdmin: isSigner || isGuardian,
            walletAddress: address,
        };
    }, [publicKey, treasury?.signers, emergency?.guardians]);
}
