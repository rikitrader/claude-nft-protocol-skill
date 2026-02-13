---
id: PUB;31
title: Trading Strategy based on BB/KC squeeze
author: LazyBear
type: indicator
tags: []
boosts: 4024
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_31
---

# Description
Trading Strategy based on BB/KC squeeze

# Source Code
```pine
//
// @author LazyBear
// @credits http://www.hiltinvestmentfund.com/html/squeeze.html
// Trading strategy based on Bollinger Bands & Keltner Channel. Added SAR / Highlights to make it really easy ;)
// v01 - initial release
//
study(shorttitle = "TS 1 [LB]", title="Trading strategy [BB / KC] [LazyBear]", overlay=true)

length = input(20, minval=1, title="Length"), mult = input(1.0, minval=0.001, maxval=50, title="MultFactor")
// showBarColor = input(true, title="Highlight Bear/Bull points (KC)", type=bool)
showBarColor = false
useTrueRange = input(false, title="Use TrueRange (KC)", type=bool)
// Note that "highlightStrategy" takes precedence over showBarColor. 
highlightStrategy = input(true, title="Highlight strategy points", type=bool)

startSAR = input(0.02, title="Start (SAR)")
incrementSAR = input(0.02, title="Increment (SAR)")
maximumSAR = input(0.2, title="Maximum (SAR)")

// Calculate BB
source = close
basis = sma(source, length)
dev = mult * stdev(source, length)
upperBB = basis + dev
lowerBB = basis - dev
plot(basis, color=red, linewidth=2)
p1 = plot(upperBB, color=red,  linewidth=2)
p2 = plot(lowerBB, color=red, linewidth=2)
fill(p1, p2, color = red)

// Calculate KC
ma = ema(source, length)
range = useTrueRange ? tr : high - low
rangema = ema(range, length)
upper = ma + rangema * mult
lower = ma - rangema * mult
c = lime
u = plot(upper, color=c, title="Upper")
plot(ma, color=c, title="Basis")
l = plot(lower, color=c, title="Lower")
fill(u, l, color=green, transp=80)

offset = 2
bearish = low < lower
bear_point = bearish ? (low-offset) : na
bear_color = bearish ? red : na
bullish = high > upper
bull_point = bullish ? (high+offset) : na
bull_color = bullish ? green : na

bar_color = bearish ? bear_color : (bullish ? bull_color : na)
plot(bear_point, color = bear_color, style=cross, linewidth=2)
plot(bull_point, color = bull_color, style=cross, linewidth=2)

bgcolor((showBarColor and not highlightStrategy) ? bar_color : na)

strat_sqz_color = ((upperBB < upper) and (lowerBB > lower)) ? yellow : blue
bgcolor(highlightStrategy ? strat_sqz_color : na)

// SAR
outSAR = sar(startSAR, incrementSAR, maximumSAR)
plot(outSAR, style=cross, color=blue)
```
