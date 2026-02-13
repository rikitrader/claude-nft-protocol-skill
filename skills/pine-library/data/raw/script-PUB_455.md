---
id: PUB;455
title: Pivot Detector Oscillator, by Giorgos E. Siligardos
author: HPotter
type: indicator
tags: []
boosts: 929
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_455
---

# Description
Pivot Detector Oscillator, by Giorgos E. Siligardos

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 26/08/2014
// The Pivot Detector Oscillator, by Giorgos E. Siligardos
// The related article is copyrighted material from Stocks & Commodities 2009 Sep
////////////////////////////////////////////////////////////
study(title="The Pivot Detector Oscillator, by Giorgos E. Siligardos")
Length_MA = input(200, minval=1)
Length_RSI = input(14, minval=1)
UpBand = input(100, minval=1)
DnBand = input(0)
MidlleBand = input(50)
hline(MidlleBand, color=black, linestyle=dashed)
hline(UpBand, color=red, linestyle=line)
hline(DnBand, color=green, linestyle=line)
xMA = sma(close, Length_MA)
xRSI = rsi(close, Length_RSI)
nRes = iff(close > xMA, (xRSI - 35) / (85-35), 
        iff(close <= xMA, (xRSI - 20) / (70 - 20), 0))
plot(nRes * 100, color=blue, title="Pivot Detector Oscillator")
```
