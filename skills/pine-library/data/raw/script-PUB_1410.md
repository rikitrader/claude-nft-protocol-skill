---
id: PUB;1410
title: Ichimoku_on_steroids v 1.0 (Scalper's) OL
author: jamc
type: indicator
tags: []
boosts: 1413
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1410
---

# Description
Ichimoku_on_steroids v 1.0 (Scalper's) OL

# Source Code
```pine
study("Ichimoku_on_steroids v 1.0 (Scalper's) OL", overlay=true)

varLo = input(title="Fast (Conversion) Line", type=integer, defval=9, minval=1, maxval=99999)
varHi = input(title="Slow (Base) Line", type=integer, defval=26, minval=1, maxval=99999)
emafreq = input(title="Ema on price frequency", type=integer, defval=2, minval=1, maxval=99999)

a = lowest(varLo)
b = highest(varLo)
c = (a + b ) / 2

d = lowest(varHi)
e = highest(varHi)
f = (d + e) / 2

//g = ((c + f) / 2)[varHi]
//h = ((highest(varHi * 2) + lowest(varHi * 2)) / 2)[varHi]

z = ema(close, emafreq)

bgcolor(z > c and z > f ? green : z < c and z < f ? red : yellow, transp=70)
plot(z, title="ema on Price", color=black)
plot(c, title="Fast (Conversion) Line", color=green)
plot(f, title="Slow (Base) Line", color=red)
```
