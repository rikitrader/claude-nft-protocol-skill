---
id: PUB;1083
title: RN MACD Signals
author: repo32
type: indicator
tags: []
boosts: 1636
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1083
---

# Description
RN MACD Signals

# Source Code
```pine
//Created by Robert N. 031115
// This will place arrows on the bottom for your MACD
//Lime up is fast over slow and under 0 line - plots under
//Lime up is fast over slow and above 0 line - plots above
//Red down is fast under slow and above 0 line - plots above
//Red down is fast under slow and under 0 line - plots under

study(title="RN MACD signals")

fastLength = input(12, minval=1), slowLength=input(26,minval=1)
signalLength=input(9,minval=1)
fastMA = ema(close, fastLength)
slowMA = ema(close, slowLength)
macd = fastMA - slowMA
signal = sma(macd, signalLength)

plotshape(macd < 0 and macd < signal,  title= "DnBelow", location=location.bottom, color=red, style=shape.arrowdown)
plotshape(macd > 0 and macd < signal,  title= "DnAbove", location=location.top, color=red, style=shape.arrowdown)
plotshape(macd < 0 and macd > signal,  title= "UpBelow", location=location.bottom, color=lime, style=shape.arrowup)
plotshape(macd > 0 and macd > signal,  title= "UpAbove", location=location.top, color=lime, style=shape.arrowup)
```
