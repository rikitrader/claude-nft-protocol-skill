---
id: PUB;1042
title: Ichimoku-Hausky Trading system
author: Hausky
type: indicator
tags: []
boosts: 310
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1042
---

# Description
Ichimoku-Hausky Trading system

# Source Code
```pine
//Created By User Hausky

study(title="Hausky100", shorttitle="Hausky100", overlay=true)
turningPeriods = input(50, minval=1, title="Tenkan-Sen")
standardPeriods = input(100, minval=1, title="Kinjun-Sen")
sts = input(true, title="Show Tenkan-Sen (50 Period)?")
sks = input(true, title="Show Kinjun-Sen (100 Period)?")

//Definitions for Tenkan-Sen (50 Period), Kinjun-Sen (100 Period)
donchian(len) => avg(lowest(len), highest(len))
turning = donchian(turningPeriods)
standard = donchian(standardPeriods)


//Plot Kijun-sen and Tenkan-sen
plot(sts and turning ? turning : na, title = 'Tenkan-Sen (50 Period)', linewidth=2, color=green)
plot(sks and standard ? standard : na, title = 'Kinjun-Sen (100 Period)', linewidth=2, color=blue)

//Definitions for EMA
src = close
EMA  = input(45, minval=1, title="EMA")
fPivot = ((high + low + close)/3)
fEMA    = ema(fPivot, EMA)

//Plot EMA
plot(fEMA, color=fuchsia, title="EMA", linewidth=2)
```
