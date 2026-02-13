---
id: PUB;2625
title: Price/OBV divergence
author: timtom85
type: indicator
tags: []
boosts: 490
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2625
---

# Description
Price/OBV divergence

# Source Code
```pine
//@version=2
study("Price/OBV divergence", "Price/OBV")
period = input(30, "Period")

// tanh(v) => (exp(v) - exp(-v))/(exp(v) + exp(-v))
// dema(x, p) => 2*ema(x, p) - ema(ema(x, p), p)

obv = cum(change(close) > 0 ? volume : change(close) < 0 ? -volume : 0*volume)

c = sign(change(ema(close, period)))
o = sign(change(ema(obv  , period)))

cc = c == o ? c : c/3*2
oo = o == c ? o : o/3*2

plot(cc, style=columns, transp = 50, color = red )
plot(oo, style=columns, transp = 50, color = blue)
```
