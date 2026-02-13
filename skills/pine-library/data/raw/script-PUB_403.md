---
id: PUB;403
title: Chaikin Volatility Strategy
author: HPotter
type: indicator
tags: []
boosts: 721
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_403
---

# Description
Chaikin Volatility Strategy

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 13/08/2014
// Chaikin's Volatility indicator compares the spread between a security's
// high and low prices. It quantifies volatility as a widening of the range
// between the high and the low price.
// You can use in the xPrice1 and xPrice2 any series: Open, High, Low, Close, HL2,
// HLC3, OHLC4 and ect...
///////////////////////////////////////////////////////////
study(title="Chaikin Volatility Strategy")
Length = input(10, minval=1)
ROCLength = input(12, minval=1)
Trigger = input(0, minval=1)
hline(0, color=purple, linestyle=line)
hline(Trigger, color=red, linestyle=line)
xPrice1 = high
xPrice2 = low
xPrice = xPrice1 - xPrice2
xROC_EMA = roc(ema(xPrice, Length), ROCLength)
pos =	iff(xROC_EMA < Trigger, 1,
	    iff(xROC_EMA > Trigger, -1, nz(pos[1], 0))) 
barcolor(pos == -1 ? red: pos == 1 ? green : blue )
plot(xROC_EMA, color=blue, title="Chaikin Volatility Strategy")
```
