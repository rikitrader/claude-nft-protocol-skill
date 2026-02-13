---
id: PUB;1784
title: ET-ATR-Price-Overlay
author: EmpoweredTrader
type: indicator
tags: []
boosts: 422
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1784
---

# Description
ET-ATR-Price-Overlay

# Source Code
```pine
// @EmpoweredTrader
// Overlays ATR high/low over price.  Shifts between support and resistance levels (based on ATR-21) according to trend and breaks.
study(title="ET-ATR-Price-Overlay", shorttitle="ATR Overlay", overlay=true) 
sd = input(true, title="Show ATR?")


atrSeries = iff(na(atrSeries[1]), close + (atr(21)*3), iff(close > atrSeries[1], 
                                                        iff(close[1] < atrSeries[1], close - (atr(21)*3), iff(atrSeries[1] < close - (atr(21)*3), close - (atr(21)*3), atrSeries[1])), 
                                                         iff(close[1] > atrSeries[1], close + (atr(21)*3), iff(atrSeries[1] < close + (atr(21)*3), atrSeries[1], close + (atr(21)*3)))))

plot(atrSeries, title="ATR level",style=circles, color=blue ,linewidth=3)





```
