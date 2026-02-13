---
id: PUB;216
title: Indicator: Weis Wave Volume [LazyBear]
author: LazyBear
type: indicator
tags: []
boosts: 18662
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_216
---

# Description
Indicator: Weis Wave Volume [LazyBear]

# Source Code
```pine
//
// @author LazyBear 
// List of all my indicators: https://www.tradingview.com/v/4IneGo8h/
//
study("Weis Wave Volume [LazyBear]", shorttitle="WWV_LB")
trendDetectionLength=input(2)
showDistributionBelowZero=input(false, type=bool)
mov = close>close[1] ? 1 : close<close[1] ? -1 : 0
trend= (mov != 0) and (mov != mov[1]) ? mov : nz(trend[1])
isTrending = rising(close, trendDetectionLength) or falling(close, trendDetectionLength) //abs(close-close[1]) >= dif
wave=(trend != nz(wave[1])) and isTrending ? trend : nz(wave[1])
vol=wave==wave[1] ? (nz(vol[1])+volume) : volume
up=wave == 1 ? vol : 0
dn=showDistributionBelowZero ? (wave == 1 ? 0 : wave == -1 ? -vol : vol) : (wave == 1 ? 0 : vol)
plot(up, style=histogram, color=green, linewidth=3)
plot(dn, style=histogram, color=red, linewidth=3)

```
