---
id: PUB;1431
title: Madrid Bollinger Bands %D
author: Madrid
type: indicator
tags: []
boosts: 357
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1431
---

# Description
Madrid Bollinger Bands %D

# Source Code
```pine
// BB %B : Hector R. Madrid : 06/JUN/2014 23:36 : 1.0
// This displays the distance from the lower band in terms of percentage
// The farther it is from the basis line, the stronger the trend.
// When the price exceedes the 100% or it's below 0% it means the price has
// reached an overbought (above 100) or oversold (below 0) level. 

study(title = "Madrid Bollinger Bands %D", shorttitle = "MBB %D", precision=0)
src = input(close, type="source")
length = input(34, minval=1, type=integer)
mult = input(2.0, minval=0.001, maxval=50, type=float)
smooth = input(defval=true, type=bool)

basis = sma(src, length)
dev = stdev(src, length)
dev2 = mult*dev

upper1 = basis + dev
lower1 = basis - dev
upper2 = basis + dev2
lower2 = basis - dev2

bbr = smooth ? sma((src - lower2)/(upper2 - lower2) * 100, 3)
      : (src - lower2)/(upper2 - lower2) * 100
bbrMA = ema(bbr, 13)

// Output
bbrColor = bbr >=50 ? blue : orange
plot(bbr, color=bbrColor, linewidth=2)

hline(0, color=orange, linewidth=1, linestyle=dotted)
hline(100, color=navy, linewidth=1, linestyle=dotted)
hline(50, color=gray, linewidth=1, linestyle=dotted)

```
