---
id: PUB;201
title: Historical Volatility Strategy
author: HPotter
type: indicator
tags: []
boosts: 1015
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_201
---

# Description
Historical Volatility Strategy

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 16/07/2014
// Strategy buy when HVol above BuyBand and close position when HVol below CloseBand.
// Markets oscillate from periods of low volatility to high volatility 
// and back. The author`s research indicates that after periods of 
// extremely low volatility, volatility tends to increase and price 
// may move sharply. This increase in volatility tends to correlate 
// with the beginning of short- to intermediate-term moves in price. 
// They have found that we can identify which markets are about to make 
// such a move by measuring the historical volatility and the application 
// of pattern recognition.
// The indicator is calculating as the standard deviation of day-to-day 
// logarithmic closing price changes expressed as an annualized percentage.
////////////////////////////////////////////////////////////
study(title="Historical Volatility")
LookBack = input(20, minval=1)
Annual = input(365, minval=1)
BuyBand = input(20, minval=1)
CloseBand = input(10, minval=1)
hline(0, color=purple, linestyle=dashed)
hline(BuyBand, color=green, linestyle=line)
hline(CloseBand, color=red, linestyle=line)
xPrice = log(close / close[1])
nPer = iff(isintraday or isdaily, 1, 7)
xPriceAvg = sma(xPrice, LookBack)
xStdDev = stdev(xPrice, LookBack)
HVol = (xStdDev * sqrt(Annual / nPer)) * 100
pos =	iff(HVol > BuyBand, 1, 
            iff(HVol < CloseBand, -1, nz(pos[1], 0))) 
barcolor(pos == 1 ? yellow : na)
plot(HVol, color=blue, title="Historical Volatility")
```
