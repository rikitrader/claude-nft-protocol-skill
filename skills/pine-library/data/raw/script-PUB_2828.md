---
id: PUB;2828
title: KT_Smooth_Stochastic
author: ktuimala
type: indicator
tags: []
boosts: 228
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2828
---

# Description
KT_Smooth_Stochastic

# Source Code
```pine
// Title: Smooth Stochastic
// Author: Kaleb Tuimala
// Date: 06/25/2016
//
// Description: A standard implementation of a smoothed Fast Stochastic.
//              The %K and %D are smoothed n periods after they are calculated.
//
//@version=2
study(title="KT_Smooth_Stochastic", shorttitle="Smooth Stochastic")
periodK = input(14, minval=1, title="%K")
periodD = input(7, minval=1, title="%D")
smooth = input(3, minval=1, title="Smooth")

k = stoch(close, high, low, periodK)
d = sma(k, periodD)

sK = sma(k, smooth)
sD = sma(d, smooth)

uL = hline(80, color=black, linestyle=solid, linewidth=2, title="Upper Line")
mL = hline(50, color=green, linestyle=solid, linewidth=2, title="Middle Line")
lL = hline(20, color=purple, linestyle=solid, linewidth=2, title="Lower Line")

fill(uL, lL, color=gray, transp=80, title="Shaded Region")

plot(sK, color=blue, linewidth=2, title="%K")
plot(sD, color=red, linewidth=2, title="%D")
```
