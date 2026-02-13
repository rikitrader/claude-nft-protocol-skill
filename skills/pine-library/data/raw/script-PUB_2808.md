---
id: PUB;2808
title: Sniper Stochastics 2
author: SpreadEagle71
type: indicator
tags: []
boosts: 326
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2808
---

# Description
Sniper Stochastics 2

# Source Code
```pine
study(title="Sniper Stochastics 2", shorttitle="Snp Stoch2")
plotchar = location.top
length1 = input(55, minval=1), smoothK1 = input(1, minval=1), smoothD1 = input(3, minval=1)
length2 = input(89, minval=1), smoothK2 = input(1, minval=1), smoothD2 = input(1, minval=1)
length3 = input(144,minval=1),smoothk3 = input(1,minval=1),smoothD3 = input(1,minval=1)
k1 = sma(stoch(close, high, low, length1), smoothK1)
d1 = sma(k1, smoothD1)
plot(k1, color=black)
k2 = sma(stoch(close, high, low, length2), smoothK2)
d2 = sma(k2, smoothD2)
plot(k2, color=blue)
k3 = sma(stoch(close,high,low,length3),smoothk3)
d3 = sma(k3,smoothD3)
plot(k3,color=red)

```
