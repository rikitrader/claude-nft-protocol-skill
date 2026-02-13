---
id: PUB;361
title: TheLark: Directional Movement Index Stochastic
author: TheLark
type: indicator
tags: []
boosts: 1509
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_361
---

# Description
TheLark: Directional Movement Index Stochastic

# Source Code
```pine
study(title="TheLark: Directional Movement Index Stochastic", shorttitle="DMISTO_LK", overlay=false)

        //•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•//   
        //                                             //
        //              DMISTO BY THELARK              //
        //                 ~ 8-4-14 ~                  //
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
DMIlength = input(10,title="DMI Length")
Avglength = input(3, title="Avg Length")
ShowDots = input(true)
ob = input(90,title="Over Bought")
os = input(10,title="Over Sold")

// Osc Calc
hiDiff = high - high[1]
loDiff = low[1] - low
plusDM = (hiDiff > loDiff) and (hiDiff > 0) ? hiDiff : 0
minusDM = (loDiff > hiDiff) and (loDiff > 0) ? loDiff : 0
ATR = wwma(DMIlength, tr)
PlusDI = 100 * wwma(DMIlength,plusDM) / ATR
MinusDI = 100 * wwma(DMIlength,minusDM) / ATR
osc = PlusDI - MinusDI

// STO
hh = highest(osc,DMIlength)
ll = lowest(osc,DMIlength)
sto = 100 * (osc-ll) / (hh-ll)
kslow = sma(sto, Avglength)
perd = sma(kslow,Avglength)

// Plots
plot(ob,color=gray)
plot(os,color=gray)
plot(ShowDots ? kslow[1] < perd[1] and kslow > perd and perd < os ? os : na : na,style=circles,color=lime,linewidth=2)
plot(ShowDots ? kslow[1] > perd[1] and kslow < perd and perd > ob ? ob : na : na,style=circles,color=orange,linewidth=2)
plot(kslow, color=#0EAAEF,title="DMISTO-slow",linewidth=1)
plot(perd, color=red,title="DMISTO-slow",linewidth=1)
//plot(sto, color=#0EAAEF,title="DMISTO",linewidth=1)
```
