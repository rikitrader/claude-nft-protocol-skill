---
id: PUB;3074
title: Full Stochastic
author: box-box-box
type: indicator
tags: []
boosts: 648
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_3074
---

# Description
Full Stochastic

# Source Code
```pine
// based on SlowStoch by Oshri17
study(title="Full Stochastic", shorttitle="FullStoch")
lookback_period = input(14, minval=1), m1 = input(3, minval=1), m2 = input(3, minval=1)

k = sma(stoch(close, high, low, lookback_period), m1)
d = sma(k, m2)
plot(k, color=black)
plot(d, color=red)
h0 = hline(80)
h1 = hline(20)
fill(h0, h1, color=purple, transp=95)
```
