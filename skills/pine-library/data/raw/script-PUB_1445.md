---
id: PUB;1445
title: Trend Trading With Moving Averages (by ChartArt)
author: ChartArt
type: indicator
tags: []
boosts: 2461
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1445
---

# Description
Trend Trading With Moving Averages (by ChartArt)

# Source Code
```pine
study(title="Trend Trading With Moving Averages (by ChartArt)", shorttitle="CA_-_Trend_MA", overlay=true)

// ChartArt's Optimized Steve Primo's Robbery Indicator
//
// Version 1.0
// Idea by ChartArt on June 18, 2015.
//
// This indicator is measuring if there are three
// different moving averages with the same period aligned
// in the same trend direction. If this is the case then
// the bar is colored in green. If only one or two of the
// three moving averages signals an uptrend then the
// bar is colored in blue. This can mean that
// the trend is changing.
//
// Original idea: Steve Primo's Robbery Indicator (PET-D)
// as published by UCSGears on Tradingview.
//
// List of my work: 
// https://www.tradingview.com/u/ChartArt/

MAlength = input(15, title="Length of Moving Averages")

petd = ema(close, MAlength)
petx = wma(close, MAlength)
pety = sma(close, MAlength)

up = (close > petd) and (close > petx) and (close > pety) ? green : (close > petd) or (close > petx) or (close > pety) ? blue : red

barcolor(up)

```
