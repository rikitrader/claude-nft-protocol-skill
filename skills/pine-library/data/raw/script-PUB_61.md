---
id: PUB;61
title: FVE Volatility color-coded Volume bar
author: HPotter
type: indicator
tags: []
boosts: 903
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_61
---

# Description
FVE Volatility color-coded Volume bar

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 03/06/2014
// The FVE is a pure volume indicator. Unlike most of the other indicators 
// (except OBV), price change doesn?t come into the equation for the FVE 
// (price is not multiplied by volume), but is only used to determine whether 
// money is flowing in or out of the stock. This is contrary to the current trend 
// in the design of modern money flow indicators. The author decided against a 
// price-volume indicator for the following reasons:
// - A pure volume indicator has more power to contradict.
// - The number of buyers or sellers (which is assessed by volume) will be the same, 
// regardless of the price fluctuation.
// - Price-volume indicators tend to spike excessively at breakouts or breakdowns.
// This study is an addition to FVE indicator. Indicator plots different-coloured volume 
// bars depending on volatility.
////////////////////////////////////////////////////////////
study(title="Volatility Finite Volume Elements", shorttitle="FVI")
Samples = input(22, minval=1)
AvgLength = input(50, minval=1)
AlertPct = input(70, minval=1)
Cintra = input(0.1)
Cinter = input(0.1)
xVolume = volume
xClose = close
xhl2 = hl2
xhlc3 = hlc3
xMA = sma(xVolume, AvgLength)
xIntra = log(high) - log(low)
xInter = log(xhlc3) - log(xhlc3[1])
xStDevIntra = stdev(sma(xIntra, Samples) , Samples)
xStDevInter = stdev(sma(xInter, Samples) , Samples)
TP = xhlc3
TP1 = xhlc3[1]
Intra = xIntra
Vintra = xStDevIntra
Inter = xInter
Vinter = xStDevInter
CutOff = Cintra * Vintra + Cinter * Vinter
MF = xClose - xhl2 + TP - TP1
clr = iff(MF > CutOff * xClose, green, 
             iff(MF < -1 * CutOff * xClose, red,  blue))
plot(xVolume, color=clr, title="VBF")
plot(xMA, color=blue, title="VBF EMA")
```
