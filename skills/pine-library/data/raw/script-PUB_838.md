---
id: PUB;838
title: Slow Stochastic
author: Oshri17
type: indicator
tags: []
boosts: 8948
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_838
---

# Description
Slow Stochastic

# Source Code
```pine
study(title="Slow Stochastic", shorttitle="SlowStoch")
smoothK = input(14, minval=1), smoothD = input(3, minval=1)
k = sma(stoch(close, high, low, smoothK), 3)
d = sma(k, smoothD)
plot(k, color=black)
plot(d, color=red)
h0 = hline(80)
h1 = hline(20)
fill(h0, h1, color=purple, transp=95)
```
