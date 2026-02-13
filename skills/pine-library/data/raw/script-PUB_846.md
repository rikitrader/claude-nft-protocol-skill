---
id: PUB;846
title: UCS_Squeeze_Optimization
author: UDAY_C_Santhakumar
type: indicator
tags: []
boosts: 1257
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_846
---

# Description
UCS_Squeeze_Optimization

# Source Code
```pine
// Heikin Ashi Optimization Applied

study(shorttitle = "UCS_SQZ_Opt", title="UCS_Squeeze Momentum - Optimized", overlay=false)

length = input(20, title="Squeeze Length")
multBB = input(2,title="BB MultFactor")
multKC = input(1.5, title="KC MultFactor")
smooth = input(20, title = "Momentum Smoothing")

usebbr = input(true, title = "Use Bollinger Band Ratio Instead of Momentum", type = bool)
useHAC = input(true, title = "Heikin Ashi Optimization", type=bool)

// Heikin Ashi ATR Calculations
haclose = ohlc4
haopen = na(haopen[1]) ? (open + close)/2 : (haopen[1] + haclose[1]) / 2
hahigh = max (high, max(haopen,haclose))
halow = min (low, min(haopen,haclose))
haatra = abs(hahigh - haclose[1])
haatrb = abs(haclose[1] - halow)
haatrc = abs(hahigh - halow)
haatr = max(haatra, max(haatrb,haatrc))

source = useHAC ? haclose : close

// Calculate BB
basis = sma(source, length)
dev = multBB * stdev(source, length)
upperBB = basis + dev
lowerBB = basis - dev


// Calculate KC
ma = sma(source, length)
range = useHAC ? haatr : tr
rangema = sma(range, length)
upperKC = ma + rangema * multKC
lowerKC = ma - rangema * multKC

sqzOn  = (lowerBB > lowerKC) and (upperBB < upperKC)
sqzOff = (lowerBB < lowerKC) and (upperBB > upperKC)
noSqz  = (sqzOn == false) and (sqzOff == false)

// Momentum ======> %B Indicator OR Rate of Change (ROC)
momentum = usebbr ? (((source - lowerBB)/(upperBB - lowerBB))-0.5) : (((close - close[12])/close[12])*100)
val = sma(momentum,smooth)

// Plot Statements
bcolor = iff( val > 0, 
            iff( val > nz(val[1]), green, blue),
            iff( val < nz(val[1]), red, orange))
scolor = noSqz ? blue : sqzOn ? red : green 
plot(val, color=bcolor, style=histogram, linewidth=3)
plot(0, color=scolor, style=circles, linewidth=3)
```
