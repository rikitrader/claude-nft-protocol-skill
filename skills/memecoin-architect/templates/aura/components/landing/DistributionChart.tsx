"use client";

import React from "react";
import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip } from "recharts";

const DISTRIBUTION = [
    { name: "Liquidity Pool", value: 70, color: "#00F0FF" },
    { name: "Community", value: 15, color: "#9B59FF" },
    { name: "Treasury DAO", value: 10, color: "#FF6B35" },
    { name: "Team (Vested)", value: 5, color: "#FFFFFF33" },
];

export function DistributionChart() {
    return (
        <div className="flex flex-col items-center gap-6 sm:flex-row sm:items-start">
            <div className="h-56 w-56 shrink-0">
                <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                        <Pie
                            data={DISTRIBUTION}
                            cx="50%"
                            cy="50%"
                            innerRadius={60}
                            outerRadius={90}
                            dataKey="value"
                            strokeWidth={0}
                            animationDuration={1200}
                        >
                            {DISTRIBUTION.map((entry) => (
                                <Cell key={entry.name} fill={entry.color} />
                            ))}
                        </Pie>
                        <Tooltip
                            contentStyle={{
                                background: "rgba(0,0,0,0.8)",
                                border: "1px solid rgba(255,255,255,0.1)",
                                borderRadius: 8,
                                color: "#fff",
                                fontSize: 12,
                            }}
                            formatter={(value: number) => `${value}%`}
                        />
                    </PieChart>
                </ResponsiveContainer>
            </div>
            <div className="space-y-3">
                {DISTRIBUTION.map((d) => (
                    <div key={d.name} className="flex items-center gap-3">
                        <span
                            className="h-3 w-3 shrink-0 rounded-full"
                            style={{ background: d.color }}
                        />
                        <span className="text-sm text-white/70">{d.name}</span>
                        <span className="ml-auto text-sm font-bold text-white">{d.value}%</span>
                    </div>
                ))}
            </div>
        </div>
    );
}
