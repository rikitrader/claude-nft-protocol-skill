---
id: PUB;539
title: Average True Range Trailing Stops Strategy
author: HPotter
type: indicator
tags: []
boosts: 2447
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_539
---

# Description
Average True Range Trailing Stops Strategy

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 16/09/2014
// Average True Range Trailing Stops Strategy, by Sylvain Vervoort 
// The related article is copyrighted material from Stocks & Commodities Jun 2009 
////////////////////////////////////////////////////////////
study(title="Average True Range Trailing Stops Strategy, by Sylvain Vervoort", overlay = true)
nATRPeriod = input(5)
nATRMultip = input(3.5)
xATR = atr(nATRPeriod)
nLoss = nATRMultip * xATR
xATRTrailingStop = iff(close > nz(xATRTrailingStop[1], 0) and close[1] > nz(xATRTrailingStop[1], 0), max(nz(xATRTrailingStop[1]), close - nLoss),
                    iff(close < nz(xATRTrailingStop[1], 0) and close[1] < nz(xATRTrailingStop[1], 0), min(nz(xATRTrailingStop[1]), close + nLoss), 
                        iff(close > nz(xATRTrailingStop[1], 0), close - nLoss, close + nLoss)))
pos =	iff(close[1] < nz(xATRTrailingStop[1], 0) and close > nz(xATRTrailingStop[1], 0), 1,
	    iff(close[1] > nz(xATRTrailingStop[1], 0) and close < nz(xATRTrailingStop[1], 0), -1, nz(pos[1], 0))) 
barcolor(pos == -1 ? red: pos == 1 ? green : blue )
plot(xATRTrailingStop, color=red, title="ATR Trailing Stop")


```
