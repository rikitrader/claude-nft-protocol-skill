---
id: PUB;708
title: Kijun Bands
author: IvanLabrie
type: indicator
tags: []
boosts: 500
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_708
---

# Description
Kijun Bands

# Source Code
```pine
study(title = "Kijun sen on Bollinger Bands", shorttitle="Kijun+BB")
middleDonchian(Length) =>
    lower = lowest(Length)
    upper = highest(Length)
    avg(upper, lower)

basePeriods = input(26, minval=1)
displacement = input(26, minval=1)
Kijun =  middleDonchian(basePeriods)
xChikou = close
xPrice = close
plot(Kijun, color=blue, title="Kijun")
plot(xChikou, color= teal , title="Chikou", offset = -displacement)
plot(xPrice, color= yellow , title="Price")

BB_length = input(24, minval=1, maxval=50)
BB_stdDev = input(2, minval=2.0, maxval=3)

bb_s = Kijun
basis = sma(bb_s, BB_length)
dev = BB_stdDev * stdev(bb_s, BB_length)
upper = basis + dev
lower = basis - dev
plot(basis, color=red)
p1 = plot(upper, color=blue)
p2 = plot(lower, color=blue)
fill(p1,p2, blue)
```
