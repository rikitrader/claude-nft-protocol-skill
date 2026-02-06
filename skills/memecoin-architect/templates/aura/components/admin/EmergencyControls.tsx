"use client";

import React, { useState, useMemo } from "react";
import { SystemProgram, type TransactionInstruction } from "@solana/web3.js";
import { useEmergencyStatus } from "@/hooks/useEmergencyStatus";
import { useRoleGuard } from "@/hooks/useRoleGuard";
import { shortenAddress } from "@/lib/formatters";
import { TransactionButton } from "./TransactionButton";

export function EmergencyControls() {
    const { data, isLoading } = useEmergencyStatus();
    const { walletAddress } = useRoleGuard();
    const [confirmAction, setConfirmAction] = useState<"pause" | "resume" | null>(null);

    const hasVotedPause = data?.pauseVotes.includes(walletAddress ?? "") ?? false;
    const hasVotedResume = data?.resumeVotes.includes(walletAddress ?? "") ?? false;

    // Placeholder instructions — replace with actual Anchor vote_pause/vote_resume
    const pauseInstructions = useMemo((): TransactionInstruction[] => {
        if (confirmAction !== "pause") return [];
        return [SystemProgram.transfer({ fromPubkey: SystemProgram.programId, toPubkey: SystemProgram.programId, lamports: 0 })];
    }, [confirmAction]);

    const resumeInstructions = useMemo((): TransactionInstruction[] => {
        if (confirmAction !== "resume") return [];
        return [SystemProgram.transfer({ fromPubkey: SystemProgram.programId, toPubkey: SystemProgram.programId, lamports: 0 })];
    }, [confirmAction]);

    if (isLoading) {
        return <div className="h-40 animate-pulse rounded-lg bg-white/5" />;
    }

    return (
        <div className="space-y-6">
            {/* Current state */}
            <div className="flex items-center gap-3 rounded-xl border border-white/10 bg-white/5 p-4">
                <span className={`h-4 w-4 rounded-full ${data?.isPaused ? "bg-rose-500 animate-pulse" : "bg-emerald-500"}`} />
                <span className={`text-lg font-bold ${data?.isPaused ? "text-rose-400" : "text-emerald-400"}`}>
                    {data?.isPaused ? "SYSTEM PAUSED" : "SYSTEM OPERATIONAL"}
                </span>
            </div>

            {/* Guardian votes */}
            <div className="grid gap-4 sm:grid-cols-2">
                <div>
                    <p className="mb-2 text-xs text-white/40">Pause Votes ({data?.pauseVotes.length ?? 0})</p>
                    {data?.pauseVotes.map((v) => (
                        <span key={v} className="mr-1 inline-block rounded-full bg-rose-500/20 px-2 py-0.5 font-mono text-[10px] text-rose-400">
                            {shortenAddress(v)}
                        </span>
                    ))}
                </div>
                <div>
                    <p className="mb-2 text-xs text-white/40">Resume Votes ({data?.resumeVotes.length ?? 0})</p>
                    {data?.resumeVotes.map((v) => (
                        <span key={v} className="mr-1 inline-block rounded-full bg-emerald-500/20 px-2 py-0.5 font-mono text-[10px] text-emerald-400">
                            {shortenAddress(v)}
                        </span>
                    ))}
                </div>
            </div>

            {/* Guardians list */}
            <div>
                <p className="mb-2 text-xs text-white/40">Guardians ({data?.guardians.length ?? 0})</p>
                <div className="flex flex-wrap gap-1">
                    {data?.guardians.map((g) => (
                        <span key={g} className="rounded-full bg-[#9B59FF]/20 px-3 py-1 font-mono text-xs text-[#9B59FF]">
                            {shortenAddress(g)}
                        </span>
                    ))}
                </div>
            </div>

            {/* Actions */}
            <div className="flex gap-3">
                {!data?.isPaused && !hasVotedPause && (
                    <>
                        {confirmAction === "pause" ? (
                            <div className="flex items-center gap-2">
                                <span className="text-sm text-rose-400">Confirm pause vote?</span>
                                <TransactionButton label="Confirm" instructions={pauseInstructions} onSuccess={() => setConfirmAction(null)} />
                                <button onClick={() => setConfirmAction(null)} className="text-sm text-white/40 hover:text-white">Cancel</button>
                            </div>
                        ) : (
                            <button
                                onClick={() => setConfirmAction("pause")}
                                className="rounded-xl border border-rose-500/30 px-6 py-2.5 text-sm font-bold text-rose-400 transition-colors hover:bg-rose-500/10"
                            >
                                Vote Pause
                            </button>
                        )}
                    </>
                )}
                {data?.isPaused && !hasVotedResume && (
                    <>
                        {confirmAction === "resume" ? (
                            <div className="flex items-center gap-2">
                                <span className="text-sm text-emerald-400">Confirm resume vote?</span>
                                <TransactionButton label="Confirm" instructions={resumeInstructions} onSuccess={() => setConfirmAction(null)} />
                                <button onClick={() => setConfirmAction(null)} className="text-sm text-white/40 hover:text-white">Cancel</button>
                            </div>
                        ) : (
                            <button
                                onClick={() => setConfirmAction("resume")}
                                className="rounded-xl border border-emerald-500/30 px-6 py-2.5 text-sm font-bold text-emerald-400 transition-colors hover:bg-emerald-500/10"
                            >
                                Vote Resume
                            </button>
                        )}
                    </>
                )}
                {hasVotedPause && !data?.isPaused && (
                    <span className="text-sm text-amber-400">You have voted to pause.</span>
                )}
                {hasVotedResume && data?.isPaused && (
                    <span className="text-sm text-amber-400">You have voted to resume.</span>
                )}
            </div>
        </div>
    );
}
