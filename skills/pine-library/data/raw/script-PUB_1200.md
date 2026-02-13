---
id: PUB;1200
title: [RS][JR]RSI Donchian Channels
author: QuantitativeExhaustion
type: indicator
tags: []
boosts: 899
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1200
---

# Description
[RS][JR]RSI Donchian Channels

# Source Code
```pine
study(title="[RS][JR]RSI Donchian Channels", shorttitle="[RS][JR]RSI DC", overlay=false)
src = input(defval=close, type=source, title="RSI Source:")
rsi_length = input(defval=14, minval=1, title="RSI Period Length:")
donchian_length = input(20, minval=1, title="Donchian Lookback Period Length:")

rsi1 = rsi(src, rsi_length)

lower = lowest(rsi1, donchian_length)
upper = highest(rsi1, donchian_length)
basis = avg(upper, lower)

plot(rsi1, color=aqua)
l = plot(lower, color=blue)
u = plot(upper, color=blue)
plot(basis, color=orange)
fill(u, l, color=blue)

hline(0)
hline(50)
hline(100)
```
