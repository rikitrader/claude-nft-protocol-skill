---
id: PUB;1912
title: RSI-EMA Indicator
author: Stable_Camel
type: indicator
tags: []
boosts: 845
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1912
---

# Description
RSI-EMA Indicator

# Source Code
```pine
study(title="marsi", shorttitle="marsi", overlay=false)

basis = rsi(close, input(50))

ma1 = ema(basis, input(100))
ma2 = ema(basis, input(200))

oversold = input(40)
overbought = input(60)

plot(ma1, title="RSI EMA1", color=blue)
plot(ma2, title="RSI EMA2", style=line, color=green)

obhist = ma1 >= overbought ? ma1 : overbought
oshist = ma1 <= oversold ? ma1 : oversold

plot(obhist, title="Overbought Highligth", style=histogram, color=maroon, histbase=overbought)
plot(oshist, title="Oversold Highligth", style=histogram, color=green, histbase=oversold)

i1 = hline(oversold, title="Oversold Level", color=white)
i2 = hline(overbought, title="Overbought Level", color=white)

fill(i1, i2, color=olive, transp=100)

hline(50, title="50 Level", color=white)
```
