---
id: PUB;757
title: UCS_Squeeze_Timing-V2
author: UDAY_C_Santhakumar
type: indicator
tags: []
boosts: 520
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_757
---

# Description
UCS_Squeeze_Timing-V2

# Source Code
```pine
// Variation - Lazybear Squeeze Indicator
// Recreated and Modified by UCSgears
// Replaced the momentum indicator 

study(shorttitle = "UCS_SQUEEZE_Timing_V2", title="Squeeze Momentum Timing and Direction", overlay=false)

lengthBB = input(20, title="BB Length")
multBB = input(2,title="BB MultFactor")
lengthKC=input(20, title="KC Length")
multKC = input(1.5, title="KC MultFactor")

useTrueRange = input(true, title="Use TrueRange (KC)", type=bool)

// Calculate BB
source = close
basis = sma(source, lengthBB)
dev = multBB * stdev(source, lengthBB)
upperBB = basis + dev
lowerBB = basis - dev

// Calculate KC
ma = sma(source, lengthKC)
range = useTrueRange ? tr : (high - low)
rangema = sma(range, lengthKC)
upperKC = ma + rangema * multKC
lowerKC = ma - rangema * multKC

sqzOn  = (lowerBB > lowerKC) and (upperBB < upperKC)
sqzOff = (lowerBB < lowerKC) and (upperBB > upperKC)
noSqz  = (sqzOn == false) and (sqzOff == false)

bbr = ((source - lowerBB)/(upperBB - lowerBB))-0.5

val = sma(bbr,20)

bcolor = iff( val > 0, 
            iff( val > nz(val[1]), green, blue),
            iff( val < nz(val[1]), red, orange))
scolor = noSqz ? blue : sqzOn ? red : green 
plot(val, color=bcolor, style=histogram, linewidth=3)
plot(0, color=scolor, style=circles, linewidth=3)
```
