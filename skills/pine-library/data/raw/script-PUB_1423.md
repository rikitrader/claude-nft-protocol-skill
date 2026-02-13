---
id: PUB;1423
title: Consecutive Candle Count
author: DRodriguezFX
type: indicator
tags: []
boosts: 729
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1423
---

# Description
Consecutive Candle Count

# Source Code
```pine
study("Consecutive Candle Count")
barup = close > close[1]
bardown = close < close[1]
plot(series=barssince(barup)*-1, title="Consecutive Bars Down", color=red, style=histogram, linewidth=2)
plot(series=barssince(bardown), title="Consecutive Bars Up", color=green, style=histogram, linewidth=2)
//Adaptation of http://www.fxcmapps.com/trading-station/consecutive-bars/ from FXCM's Marketscope
//Coded by David Rodriguez, Quantitative Strategist for DailyFX.com
```
