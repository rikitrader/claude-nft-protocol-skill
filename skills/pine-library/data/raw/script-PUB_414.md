---
id: PUB;414
title: Indicators: Hurst Bands and Hurst Oscillator
author: LazyBear
type: indicator
tags: []
boosts: 1961
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_414
---

# Description
Indicators: Hurst Bands and Hurst Oscillator

# Source Code
```pine
//
// @author LazyBear
//
// If you use this code in its original/modified form, do drop me a note. 
//
study("Hurst Bands [LazyBear]", shorttitle="H%Bands_LB", overlay=true)
price = hl2
length = input(10, title="Displacement length")
InnerValue = input(1.6, title="Innerbands %")
OuterValue = input(2.6, title="Outerbands %")
ExtremeValue = input(4.2, title="Extremebands %")
showExtremeBands = input(false, type=bool, title="Display Extreme Bands?")
showClosingPriceLine = input(false, type=bool, title="Plot Close price?")
smooth = input(1, title="EMA Length for Close")

displacement = (length / 2) + 1
dPrice = price[displacement]

CMA = not na(dPrice) ?  sma(dPrice, abs(length)) : nz(CMA[1]) + (nz(CMA[1]) - nz(CMA[2]))
 
CenteredMA=plot(not na(dPrice) ? CMA : na, color=blue , linewidth=2)
CenterLine=plot(not na(price) ? CMA : na, linewidth=2, color=aqua)

ExtremeBand = CMA * ExtremeValue / 100
OuterBand   = CMA * OuterValue / 100
InnerBand   = CMA * InnerValue / 100

UpperExtremeBand=plot(showExtremeBands and (not na(price)) ? CMA + ExtremeBand : na)
LowerExtremeBand=plot(showExtremeBands and (not na(price)) ? CMA - ExtremeBand : na)
UpperOuterBand=  plot(not na(price) ? CMA + OuterBand : na)
LowerOuterBand=  plot(not na(price) ? CMA - OuterBand : na)
UpperInnerBand=  plot(not na(price) ? CMA + InnerBand : na)
LowerInnerBand=  plot(not na(price) ? CMA - InnerBand : na)

fill(UpperOuterBand, UpperInnerBand, color=red, transp=85)
fill(LowerInnerBand, LowerOuterBand, color=green, transp=85)

FlowValue = close > close[1] ? high : close < close[1] ? low : hl2
FlowPrice = plot(showClosingPriceLine ? sma(FlowValue, smooth) : na, linewidth=1)

```
