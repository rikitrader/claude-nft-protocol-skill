---
id: PUB;977
title: Trend BUY Signal
author: Swamikan_RajaJesupatham
type: indicator
tags: []
boosts: 2189
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_977
---

# Description
Trend BUY Signal

# Source Code
```pine
study("Trend BUY Signal")
ma1 = 10, ma2 = 30, ma3 = 200, lval = 100, pc = 3.5
MvgAvg1 = ema(close, ma1)
MvgAvg2 = ema(close, ma2)
MvgAvg3 = ema(close, ma3)
LowVal = lowest(lval)
pcChange = (1+(pc/100))*LowVal

signal = iff(((MvgAvg1 > MvgAvg2) and (close > MvgAvg3) and (close > pcChange)),1,0)
plot(signal)
```
