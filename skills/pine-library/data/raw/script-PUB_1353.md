---
id: PUB;1353
title: TonyUX EMA Scalper - Buy / Sell
author: tux
type: indicator
tags: []
boosts: 18958
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1353
---

# Description
TonyUX EMA Scalper - Buy / Sell

# Source Code
```pine
study(title="Tony's EMA Scalper - Buy / Sell", shorttitle="TUX EMA Scalper", overlay=true)
len = input(20, minval=1, title="Length")
src = input(close, title="Source")
out = ema(src, len)
plot(out, title="EMA", color=blue)
last8h = highest(close, 8)
lastl8 = lowest(close, 8)

plot(last8h, color=red, linewidth=2)
plot(lastl8, color=green, linewidth=2)


bearish = cross(close,out) == 1 and close[1] > close 
bullish = cross(close,out) == 1 and close[1] < close 

plotshape(bearish, color=red, style=shape.arrowdown, text="Sell", location=location.abovebar)
plotshape(bullish, color=green, style=shape.arrowup, text="Buy", location=location.belowbar)

```
