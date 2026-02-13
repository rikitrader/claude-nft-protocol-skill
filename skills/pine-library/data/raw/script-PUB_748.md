---
id: PUB;748
title: Stochastic Momentum Index _ UCSgears
author: UDAY_C_Santhakumar
type: indicator
tags: []
boosts: 7054
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_748
---

# Description
Stochastic Momentum Index _ UCSgears

# Source Code
```pine
//Stochastic Momentum Index
//Code by UCSgears
study("UCS_Stochastic Momentum Index", shorttitle = "UCS_SMI", overlay=false)
a = input(5, "Percent K Length")
b = input(3, "Percent D Length")
// Range Calculation
ll = lowest (low, a)
hh = highest (high, a)
diff = hh - ll
rdiff = close - (hh+ll)/2
// Nested Moving Average for smoother curves
avgrel = ema(ema(rdiff,b),b)
avgdiff = ema(ema(diff,b),b)
// SMI calculations
SMI = avgdiff != 0 ? (avgrel/(avgdiff/2)*100) : 0
SMIsignal = ema(SMI,b)
//All PLOTS
plot(SMI, title = "Stochastic Momentum Index")
plot(SMIsignal, color= red, title = "SMI Signal Line")
plot(40, color = red, title = "Over Bought")
plot(-40, color = green, title = "Over Sold")
plot(0, color = blue, title = "Zero Line")
//END
```
