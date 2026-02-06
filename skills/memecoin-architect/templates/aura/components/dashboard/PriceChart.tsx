"use client";

import React from "react";
import { ComposedChart, Bar, Line, XAxis, YAxis, Tooltip, ResponsiveContainer } from "recharts";
import { GlassCard } from "@/components/GlassCard";
import { TICKER } from "@/lib/constants";

// Placeholder data — replace with real candle data from Jupiter/Birdeye API
const MOCK_CANDLES = Array.from({ length: 24 }, (_, i) => ({
    time: `${i}:00`,
    price: 0.00042 + Math.sin(i / 3) * 0.00005 + Math.random() * 0.00002,
    volume: Math.floor(Math.random() * 50000) + 10000,
}));

export function PriceChart() {
    return (
        <GlassCard title={`${TICKER} / USDC`} className="bento-span-2">
            <div className="h-56">
                <ResponsiveContainer width="100%" height="100%">
                    <ComposedChart data={MOCK_CANDLES}>
                        <XAxis
                            dataKey="time"
                            tick={{ fill: "rgba(255,255,255,0.3)", fontSize: 10 }}
                            axisLine={false}
                            tickLine={false}
                        />
                        <YAxis
                            yAxisId="price"
                            orientation="right"
                            tick={{ fill: "rgba(255,255,255,0.3)", fontSize: 10 }}
                            axisLine={false}
                            tickLine={false}
                            tickFormatter={(v) => v.toFixed(5)}
                        />
                        <YAxis
                            yAxisId="volume"
                            orientation="left"
                            tick={false}
                            axisLine={false}
                            tickLine={false}
                        />
                        <Tooltip
                            contentStyle={{
                                background: "rgba(0,0,0,0.85)",
                                border: "1px solid rgba(255,255,255,0.1)",
                                borderRadius: 8,
                                color: "#fff",
                                fontSize: 12,
                            }}
                        />
                        <Bar
                            yAxisId="volume"
                            dataKey="volume"
                            fill="rgba(0, 240, 255, 0.15)"
                            radius={[2, 2, 0, 0]}
                        />
                        <Line
                            yAxisId="price"
                            type="monotone"
                            dataKey="price"
                            stroke="#00F0FF"
                            strokeWidth={2}
                            dot={false}
                        />
                    </ComposedChart>
                </ResponsiveContainer>
            </div>
        </GlassCard>
    );
}
