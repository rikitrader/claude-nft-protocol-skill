---
id: PUB;2447
title: Exponential Moving Average Convergence/Divergence
author: David.
type: indicator
tags: []
boosts: 1323
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2447
---

# Description
Exponential Moving Average Convergence/Divergence

# Source Code
```pine
study(title="Exponential Moving Average Convergence/Divergence", shorttitle="EMACD")
source = close
fastLength = input(12, minval=1), slowLength=input(26,minval=1)
signalLength=input(9,minval=1)
fastEMA = ema(source, fastLength)
slowEMA = ema(source, slowLength)
macd = fastEMA - slowEMA
signal = ema(macd, signalLength)
hist = macd - signal
plot(macd, color=blue)
plot(signal, color=orange)
```
