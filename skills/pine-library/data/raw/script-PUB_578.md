---
id: PUB;578
title: DMI Stochastic Extreme - 
author: UDAY_C_Santhakumar
type: indicator
tags: []
boosts: 2207
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_578
---

# Description
DMI Stochastic Extreme - 

# Source Code
```pine
// Version 0 - Created by UCS_Gears
// Version 1 - Modified by Chris Moody "Added B/S"
// Version 2 - Modified by UCS_Gears, "Replaced B/S with arrows", "Ability to change Overbought / Oversold Levels"

study(title="DMI Stochastic Extreme", shorttitle="DMI-Stochastic", overlay=false)
// Wells Wilders MA
wwma(l,p) =>
    wwma = (nz(wwma[1]) * (l - 1) + p) / l

// Inputs
DMIlength = input(10, title = "DMI Length")
Stolength = input(3, title = "Stochastic Length")
Oversold = input(10, title = "Oversold")
Overbought = input(90, title="Overbought")

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
plot(Stoch, color = gray, title = 'Stochastic', linewidth = 2, style = line)

crossUp = Stoch[1] < Oversold and Stoch > Oversold ? 1 : 0
crossDown = Stoch[1] > Overbought and Stoch < Overbought ? 1 : 0

plot (Overbought, color = red, linewidth = 1, title = 'Over Bought')
plot (Oversold, color = green, linewidth = 1, title = 'Over Sold')

plotchar(crossUp, title="Crossing Up", char='↑', location=location.bottom, color=aqua, transp=0, offset=0)
plotchar(crossDown, title="Crossing Down",char='↓', offset=0, location=location.top, color=aqua, transp=0)
```
