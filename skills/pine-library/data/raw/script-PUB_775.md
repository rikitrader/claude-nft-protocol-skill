---
id: PUB;775
title: DMI Stochastic Extereme - Version 2
author: UDAY_C_Santhakumar
type: indicator
tags: []
boosts: 2397
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_775
---

# Description
DMI Stochastic Extereme - Version 2

# Source Code
```pine
study(title="UCS_DMI Stochastic Extreme_V2", shorttitle="DMI-Sto-E_V2", overlay=false)
// Wells Wilders MA
wwma(l,p) =>
    wwma = (nz(wwma[1]) * (l - 1) + p) / l

// Inputs
DMIlength = input(10, title = "DMI Length")
Stolength = input(3, title = "DMI Stochastic Length")
os = input (10, title = "Oversold")
ob = input (90, title = "Overbought")

// DMI Osc Calc
hiDiff = high - high[1]
loDiff = low[1] - low

plusDM = (hiDiff > loDiff) and (hiDiff > 0) ? hiDiff : 0
minusDM = (loDiff > hiDiff) and (loDiff > 0) ? loDiff : 0

ATR = wwma(DMIlength, tr)

PlusDI = 100 * wwma(DMIlength,plusDM) / ATR
MinusDI = 100 * wwma(DMIlength,minusDM) / ATR

osc = PlusDI - MinusDI

// DMI Stochastic Calc
hi = highest(osc, Stolength)
lo = lowest(osc, Stolength)

Stoch = sum((osc-lo),Stolength) / sum((hi-lo),Stolength) *100
plot(Stoch, color = blue, title = 'Stochastic', linewidth = 2, style = line)

crossUp = Stoch[1] < os and Stoch > os ? 1 : 0
crossDo = Stoch[1] > ob and Stoch < ob ? 1 : 0

plot (ob, color = gray, linewidth = 1, title = 'Over Bought')
plot (os, color = gray, linewidth = 1, title = 'Over Sold')

plotchar(crossUp, title="Crossing Up Signal", char='⇑', location=location.bottom, color=green, transp=0)
plotchar(crossDo, title="Crossing Down Signal",char='⇓', location=location.top, color=red, transp=0)
```
