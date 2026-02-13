---
id: PUB;2199
title: High Low Bollinger Bands
author: SpreadEagle71
type: indicator
tags: []
boosts: 347
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2199
---

# Description
High Low Bollinger Bands

# Source Code
```pine
study(shorttitle="HL BB", title="High Low Bollinger Bands", overlay=true)
length = input(20, minval=1)
src = input(low, title="Source")
src2 = input(high, title="Source2")
mult = input(3.0, minval=0.001, maxval=50)
mult2 = input(3.0, minval=0.001, maxval=50)
basis = sma(src, length)
basis2 = sma(src2, length)
dev = mult * stdev(src, length)
dev2= mult2 * stdev(src2,length)
upper = basis2 + dev2
lower = basis - dev
plot(basis, color=orange)
plot(basis2,color=orange)
p1 = plot(upper, color=red)
p2 = plot(lower, color=blue)
fill(p1, p2)
```
