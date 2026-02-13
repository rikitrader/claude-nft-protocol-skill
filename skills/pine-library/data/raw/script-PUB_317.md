---
id: PUB;317
title: TheLark: Directional Movement Index Oscillator
author: TheLark
type: indicator
tags: []
boosts: 1266
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_317
---

# Description
TheLark: Directional Movement Index Oscillator

# Source Code
```pine
study(title="TheLark: Directional Movement Index Oscillator", shorttitle="DMI-OSC_LK", overlay=false)

        //•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•//   
        //                                             //
        //        DMI OSCILLATOR  BY THELARK           //
        //                 ~ 8-3-14 ~                  //
        //                                             //
        //                     •/•                     //
        //                                             //
        //    https://www.tradingview.com/u/TheLark    //
        //                                             //
        //•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•//

// Wells Wilders MA
wwma(l,p) =>
    wwma = (nz(wwma[1]) * (l - 1) + p) / l

// Inputs
DMIlength = input(14)
Avglength = input(2)

// Calc
hiDiff = high - high[1]
loDiff = low[1] - low
plusDM = (hiDiff > loDiff) and (hiDiff > 0) ? hiDiff : 0
minusDM = (loDiff > hiDiff) and (loDiff > 0) ? loDiff : 0
ATR = wwma(DMIlength, tr)
PlusDI = 100 * wwma(DMIlength,plusDM) / ATR
MinusDI = 100 * wwma(DMIlength,minusDM) / ATR
osc = PlusDI - MinusDI
col = osc >= 0 ? #99EF0E : #FF0064
// Plots
plot(osc,color=col, style=histogram, linewidth=2)
plot(wwma(Avglength,osc), color=#0EAAEF,title="DI+")
```
