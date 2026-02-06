"use client";

import React, { useState, useCallback } from "react";
import { useConnection, useWallet } from "@solana/wallet-adapter-react";
import { Transaction, type TransactionInstruction } from "@solana/web3.js";

type TxStatus = "idle" | "signing" | "confirming" | "success" | "error";

interface TransactionButtonProps {
    label: string;
    instructions: TransactionInstruction[];
    onSuccess?: (signature: string) => void;
    onError?: (error: Error) => void;
    disabled?: boolean;
    className?: string;
}

export function TransactionButton({
    label,
    instructions,
    onSuccess,
    onError,
    disabled = false,
    className = "",
}: TransactionButtonProps) {
    const { connection } = useConnection();
    const { publicKey, sendTransaction } = useWallet();
    const [status, setStatus] = useState<TxStatus>("idle");

    const handleClick = useCallback(async () => {
        if (!publicKey || instructions.length === 0) return;

        try {
            setStatus("signing");
            const tx = new Transaction();
            instructions.forEach((ix) => tx.add(ix));
            tx.feePayer = publicKey;
            tx.recentBlockhash = (await connection.getLatestBlockhash()).blockhash;

            setStatus("confirming");
            const signature = await sendTransaction(tx, connection);
            await connection.confirmTransaction(signature, "confirmed");

            setStatus("success");
            onSuccess?.(signature);

            // Reset after 3s
            setTimeout(() => setStatus("idle"), 3000);
        } catch (err) {
            setStatus("error");
            onError?.(err instanceof Error ? err : new Error(String(err)));
            setTimeout(() => setStatus("idle"), 3000);
        }
    }, [publicKey, instructions, connection, sendTransaction, onSuccess, onError]);

    const isDisabled = disabled || !publicKey || instructions.length === 0 || status === "signing" || status === "confirming";

    const statusStyles: Record<TxStatus, string> = {
        idle: "bg-gradient-to-r from-[#00F0FF] to-[#9B59FF] text-black",
        signing: "bg-amber-500/20 text-amber-400",
        confirming: "bg-[#00F0FF]/20 text-[#00F0FF]",
        success: "bg-emerald-500/20 text-emerald-400",
        error: "bg-rose-500/20 text-rose-400",
    };

    const statusLabels: Record<TxStatus, string> = {
        idle: label,
        signing: "Signing...",
        confirming: "Confirming...",
        success: "Success!",
        error: "Failed",
    };

    return (
        <button
            onClick={handleClick}
            disabled={isDisabled}
            className={`rounded-xl px-6 py-2.5 text-sm font-bold transition-all disabled:cursor-not-allowed disabled:opacity-50 ${statusStyles[status]} ${className}`}
        >
            {statusLabels[status]}
        </button>
    );
}
