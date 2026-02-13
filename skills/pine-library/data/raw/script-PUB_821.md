---
id: PUB;821
title: Double Stochastic
author: WaveRiders
type: indicator
tags: []
boosts: 1475
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_821
---

# Description
Double Stochastic

# Source Code
```pine
study(title="Double Stochastic", shorttitle="DBLStoch")
length1 = input(21, minval=1), smoothK1 = input(3, minval=1), smoothD1 = input(3, minval=1)
length2 = input(5, minval=1), smoothK2 = input(1, minval=1), smoothD2 = input(1, minval=1)
k1 = sma(stoch(close, high, low, length1), smoothK1)
d1 = sma(k1, smoothD1)
plot(k1, color=blue)
plot(d1, color=red)
k2 = sma(stoch(close, high, low, length2), smoothK2)
d2 = sma(k2, smoothD2)
plot(k2, color=orange)

h0 = hline(80)
h1 = hline(20)
fill(h0, h1, color = yellow, transp=90)
```
