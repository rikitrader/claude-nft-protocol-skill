---
id: PUB;1067
title: Ichimoku-Hausky_v2.1
author: Hausky
type: indicator
tags: []
boosts: 495
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1067
---

# Description
Ichimoku-Hausky_v2.1

# Source Code
```pine
//Created By User Hausky

study(title="Ichimoku-Hausky_v2.1", shorttitle="Ichi-Hausky_v2.1", overlay=true)
turningPeriods = input(18, minval=1, title="Tenkan-Sen")
standardPeriods = input(52, minval=1, title="Kinjun-Sen")
EMA  = input(45, minval=1, title="EMA")
MA  = input(104, minval=1, title="MA")
sts = input(true, title="Show Tenkan-Sen")
sks = input(true, title="Show Kinjun-Sen")

//Definitions for Tenkan-Sen, Kinjun-Sen
donchian(len) => avg(lowest(len), highest(len))
turning = donchian(turningPeriods)
standard = donchian(standardPeriods)


//Plot Kijun-sen and Tenkan-sen
plot(sts and turning ? turning : na, title = 'Tenkan-Sen', linewidth=2, color=green)
plot(sks and standard ? standard : na, title = 'Kinjun-Sen', linewidth=2, color=blue)

//Definitions for EMA
fPivot = ((high + low + close)/3)
fEMA    = ema(fPivot, EMA)

//Definitions for MA
cMA = sma(close, MA)

//Plot EMA and MA cloud
p1=plot(fEMA, color=fuchsia, title="EMA", linewidth=2)
p2=plot(cMA, color=orange, title="MA", linewidth=2)

//Fill
fill(p1, p2, color=blue, transp=75)
```
