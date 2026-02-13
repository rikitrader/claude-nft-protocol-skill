---
id: PUB;1548
title: Bollinger Band Touch
author: repo32
type: indicator
tags: []
boosts: 1161
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1548
---

# Description
Bollinger Band Touch

# Source Code
```pine
//Created by Robert Nance 7/5/15
//This script simply colors the background when price hits or exceeds the bollinger bands
//Works nice if you need a quick cue when you are playing the bounce.
study(shorttitle="BB", title="Bollinger Band Touch", overlay=true)
length = input(20, minval=1)
src = input(close, title="Source")
mult = input(2.0, minval=0.001, maxval=50)
basis = sma(src, length)
dev = mult * stdev(src, length)
upper = basis + dev
lower = basis - dev
plot(basis, color=red)
p1 = plot(upper, color=red)
p2 = plot(lower, color=green)
fill(p1, p2)
toptouch = high >= upper ? red : na
bottouch = low <= lower ? green : na

bgcolor(toptouch, transp=75)
bgcolor(bottouch, transp=75)



```
