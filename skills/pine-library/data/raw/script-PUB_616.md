---
id: PUB;616
title: Madrid Moving Average
author: Madrid
type: indicator
tags: []
boosts: 1484
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_616
---

# Description
Madrid Moving Average

# Source Code
```pine
//
// Madrid : 03/30/2014 : Moving Average : 2.0
// http://madridjourneyonws.blogspot.com/
//
// This plots the moving averages, either exponential or standard
// When it is declining it shows the MA in red, green when rising.
// Trading MA: Bullish when it is rising, Bearish when it is falling
//

study(title="Madrid Moving Average", shorttitle="MMA", overlay=true)
maLen = input(21,  minval=1, title="MA Length")
exponential = input(true)

src = close
ma = exponential ? ema(src, maLen) : sma(src, maLen)

maColor = change(ma)>0 ? green : change(ma)<0 ? red : na
plot( ma, color=maColor, style=line, title="MMA", linewidth=2)

```
