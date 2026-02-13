---
id: PUB;1318
title: Fakey pattern (Inside Bar False Breakout)
author: MLansky
type: indicator
tags: []
boosts: 1112
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1318
---

# Description
Fakey pattern (Inside Bar False Breakout)

# Source Code
```pine
//author: Khramov Vladislav

study("Fakey [KV]", overlay=true)

fakey = high[1] <= high[2] and low[1] >= low[2] and high > high[2] and close >= low[1] and close < high[2] ? red : na
fakey1 = high[1] <= high[2] and low[1] >= low[2] and low < low[2] and close > low[2] and close <= high[1] ? lime : na

bgcolor(fakey, transp=70)
bgcolor(fakey1, transp=70)
```
