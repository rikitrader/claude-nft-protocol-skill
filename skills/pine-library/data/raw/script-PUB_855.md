---
id: PUB;855
title: haDelta (developed by Dan Valcu)
author: Kumowizard
type: indicator
tags: []
boosts: 1059
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_855
---

# Description
haDelta (developed by Dan Valcu)

# Source Code
```pine
// written by Kumowizard
// special thanks to Mr. Dan Valcu, original developer of haDelta>SMA(3)
// thanks for LazyBear for writing Qstick script previously
//
// The indicator measures difference between Heikin Ashi close and open
// thus quantifies Heikin Ashi candles, to get earlier signals
// haDelta smoothed by applying 3 period SMA
//
// For further interpretation and use please check Mr. Dan Valcu's work
//

study(title="haDelta by Dan Valcu", shorttitle="haDelta+SMA")
delta = close - open
plot(delta, color=black)
s2=sma(delta, 3)
plot(s2, color = red)
plot(s2, color=red, style=area)
c_color=s2 < 0 ? (s2 < s2[1] ? red : lime) : (s2 >= 0 ? (s2 > s2[1] ? lime : red) : na)
plot(s2, color=c_color, style=circles, linewidth=2)
h0 = hline(0)
```
