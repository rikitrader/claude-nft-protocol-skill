---
id: PUB;1727
title: Capns Bollinger Bands MTF 
author: CapnOscar
type: indicator
tags: []
boosts: 353
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1727
---

# Description
Capns Bollinger Bands MTF 

# Source Code
```pine
study(shorttitle="Capns BB MTF", title="Capns Bollinger Bands MTF ", overlay=true)
BBMAMultiply = period == "1" ? 5 : period == "3" ? 5 : period == "5" ? 3 : period == "15" ? 2 : period == "30" ? 2 : period == "60" ? 4 : period == "240" ? 4 : 1

length = input(20, minval=1)
BBLength = BBMAMultiply * length
src = input(close, title="Source")
mult = input(2.0, minval=0.001, maxval=50)
basis = sma(src, BBLength)
dev = mult * stdev(src, BBLength)
upper = basis + dev
lower = basis - dev
plot(basis, color=gray, linewidth=2)
p1 = plot(upper, color=blue )
p2 = plot(lower, color=blue)
fill(p1, p2, color=green, transp=95)
out = sma(src, length)
plot(out, color=blue, title="MA")
```
