---
id: PUB;218
title: Ergotic MACD Strategy
author: HPotter
type: indicator
tags: []
boosts: 518
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_218
---

# Description
Ergotic MACD Strategy

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 17/07/2014
// This is one of the techniques described by William Blau in his book
// "Momentum, Direction and Divergence" (1995). If you like to learn more,
// we advise you to read this book. His book focuses on three key aspects
// of trading: momentum, direction and divergence. Blau, who was an electrical
// engineer before becoming a trader, thoroughly examines the relationship 
// between price and momentum in step-by-step examples. From this grounding,
// he then looks at the deficiencies in other oscillators and introduces some
// innovative techniques, including a fresh twist on Stochastics. On directional 
// issues, he analyzes the intricacies of ADX and offers a unique approach to help 
// define trending and non-trending periods.
// Blau`s indicator is like usual MACD, but it plots opposite of meaningof
// stndard MACD indicator. 
////////////////////////////////////////////////////////////
study(title="Ergotic MACD Strategy")
r = input(32, minval=1)
SmthLen = input(5, minval=1)
hline(0, color=blue, linestyle=line)
source = close
fastMA = ema(source, r)
slowMA = ema(source, 5)
xmacd = fastMA - slowMA
xMA_MACD = ema(xmacd, 5)
pos =	iff(xmacd < xMA_MACD, 1,
	    iff(xmacd > xMA_MACD, -1, nz(pos[1], 0))) 
barcolor(pos == -1 ? red: pos == 1 ? green : blue )
plot(xmacd, color=green, title="Ergotic MACD")
plot(xMA_MACD, color=red, title="SigLin")
```
