---
id: PUB;44
title: Indicator - MACD w/ 4 Color Histogram
author: ChrisMoody
type: indicator
tags: []
boosts: 979
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_44
---

# Description
Indicator - MACD w/ 4 Color Histogram

# Source Code
```pine
//Created by user ChrisMoody 2-9-14
//Created for user ericktatch
//Regular MACD Indicator with Histogram that plots 4 Colors Based on Direction Above and Below the Zero Line

study(title="CM_MACD-Histogram-Color", shorttitle="CM_MACD-Hist-Color")
source = close
fastLength = input(12, minval=1), slowLength=input(26,minval=1)
signalLength=input(9,minval=1)
fastMA = ema(source, fastLength)
slowMA = ema(source, slowLength)
macd = fastMA - slowMA
signal = sma(macd, signalLength)
hist = macd - signal
//Histogram Color Definitions
histA_IsUp = hist > hist[1] and hist > 0
histA_IsDown = hist < hist[1] and hist > 0
histB_IsDown = hist < hist[1] and hist <= 0
histB_IsUp = hist > hist[1] and hist <= 0

plot_color = histA_IsUp ? aqua : histA_IsDown ? blue : histB_IsDown ? red : histB_IsUp ? maroon : white

plot(hist, color=plot_color, style=histogram, linewidth=4)
plot(macd, title="MACD", color=red, linewidth=3)
plot(signal, title="Signal Line", color=lime, linewidth=3)
hline(0, '0 Line', linestyle=solid, linewidth=2, color=white)

```
