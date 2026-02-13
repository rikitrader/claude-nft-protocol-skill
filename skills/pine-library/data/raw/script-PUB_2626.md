---
id: PUB;2626
title: ADX and DI with SMA
author: FrancoTrading
type: indicator
tags: []
boosts: 2569
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2626
---

# Description
ADX and DI with SMA

# Source Code
```pine
study("ADX and DI with SMA")
len = input(title="Length", type=integer, defval=14)
th = input(title="threshold", type=integer, defval=20)
avg = input(title="SMA", type=integer, defval=10)

TrueRange = max(max(high-low, abs(high-nz(close[1]))), abs(low-nz(close[1])))
DirectionalMovementPlus = high-nz(high[1]) > nz(low[1])-low ? max(high-nz(high[1]), 0): 0
DirectionalMovementMinus = nz(low[1])-low > high-nz(high[1]) ? max(nz(low[1])-low, 0): 0


SmoothedTrueRange = nz(SmoothedTrueRange[1]) - (nz(SmoothedTrueRange[1])/len) + TrueRange
SmoothedDirectionalMovementPlus = nz(SmoothedDirectionalMovementPlus[1]) - (nz(SmoothedDirectionalMovementPlus[1])/len) + DirectionalMovementPlus
SmoothedDirectionalMovementMinus = nz(SmoothedDirectionalMovementMinus[1]) - (nz(SmoothedDirectionalMovementMinus[1])/len) + DirectionalMovementMinus

DIPlus = SmoothedDirectionalMovementPlus / SmoothedTrueRange * 100
DIMinus = SmoothedDirectionalMovementMinus / SmoothedTrueRange * 100
DX = abs(DIPlus-DIMinus) / (DIPlus+DIMinus)*100
ADX = sma(DX, len)
SMA = sma(ADX, avg)

plot(DIPlus, color=green, title="DI+")
plot(DIMinus, color=red, title="DI-")
plot(ADX, color=yellow, title="ADX")
plot(SMA, color=white, title="SMA")
hline(th, color=black, linestyle=dashed)
```
