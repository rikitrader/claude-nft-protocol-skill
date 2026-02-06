"use client";

import React, { useState, useMemo } from "react";
import { PublicKey, SystemProgram, type TransactionInstruction } from "@solana/web3.js";
import { TransactionButton } from "./TransactionButton";

export function CreateProposalForm() {
    const [recipient, setRecipient] = useState("");
    const [amount, setAmount] = useState("");
    const [description, setDescription] = useState("");

    const instructions = useMemo((): TransactionInstruction[] => {
        // Placeholder — replace with actual Anchor propose_transfer instruction
        // In production, use: program.methods.proposeTransfer(...)
        try {
            if (!recipient || !amount) return [];
            const recipientPubkey = new PublicKey(recipient);
            const lamports = parseFloat(amount) * 1e9;
            if (isNaN(lamports) || lamports <= 0) return [];

            // Stub: returns a memo-style instruction for development
            return [
                SystemProgram.transfer({
                    fromPubkey: PublicKey.default,
                    toPubkey: recipientPubkey,
                    lamports: 0, // Placeholder — actual IX comes from Anchor program
                }),
            ];
        } catch {
            return [];
        }
    }, [recipient, amount]);

    return (
        <div className="space-y-4">
            <div>
                <label className="mb-1 block text-xs text-white/40">Recipient Address</label>
                <input
                    type="text"
                    value={recipient}
                    onChange={(e) => setRecipient(e.target.value)}
                    placeholder="Base58 address..."
                    className="w-full rounded-lg border border-white/10 bg-white/5 px-4 py-2.5 font-mono text-sm text-white placeholder-white/20 outline-none focus:border-[#00F0FF]/40"
                />
            </div>
            <div>
                <label className="mb-1 block text-xs text-white/40">Amount (SOL)</label>
                <input
                    type="number"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    placeholder="0.00"
                    step="0.01"
                    min="0"
                    className="w-full rounded-lg border border-white/10 bg-white/5 px-4 py-2.5 text-sm text-white placeholder-white/20 outline-none focus:border-[#00F0FF]/40"
                />
            </div>
            <div>
                <label className="mb-1 block text-xs text-white/40">Description</label>
                <input
                    type="text"
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    placeholder="What is this transfer for?"
                    className="w-full rounded-lg border border-white/10 bg-white/5 px-4 py-2.5 text-sm text-white placeholder-white/20 outline-none focus:border-[#00F0FF]/40"
                />
            </div>
            <TransactionButton
                label="Create Proposal"
                instructions={instructions}
                onSuccess={() => {
                    setRecipient("");
                    setAmount("");
                    setDescription("");
                }}
            />
        </div>
    );
}
