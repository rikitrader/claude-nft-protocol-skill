---
id: PUB;1140
title: MACD Split Colors
author: blackdog6621
type: indicator
tags: []
boosts: 3674
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1140
---

# Description
MACD Split Colors

# Source Code
```pine
study(title="MACD Split Colors", shorttitle="MACD")
src = close
fastLength = input(12, minval=1), slowLength=input(26,minval=1)
signalLength=input(9,minval=1)
fastMA = ema(src, fastLength)
slowMA = ema(src, slowLength)
macd = fastMA - slowMA
signal = sma(macd, signalLength)
hist = macd - signal
pos_hist = max(0, hist)
neg_hist = min(0, hist)
plot(pos_hist, color=green, style=histogram, linewidth=2)
plot(neg_hist, color=red, style=histogram, linewidth=2)
plot(macd, color=teal)
plot(signal, color=orange)
```
