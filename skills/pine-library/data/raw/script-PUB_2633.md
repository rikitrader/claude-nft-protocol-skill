---
id: PUB;2633
title: DT Oscillator
author: psraju
type: indicator
tags: []
boosts: 762
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2633
---

# Description
DT Oscillator

# Source Code
```pine
//This is Robert C. Miner's DT Oscillator, a version of the Stochastics RSI.
//See his book, High Probability Trading Strategies
// There are four possible parameter combinations for this indicator:
//  8,5,3,3   13,8,5,5   21,13,8,8   34,21,13,13
study(title="DTOscillator", shorttitle="DTOsc")
source = close
lengthRSI = input(8, minval=8)
lengthStoch = input(5, minval=5)
smoothK = input(3, minval=3)
smoothD = input(3, minval=3)
rsi1 = rsi(source, lengthRSI)
stochRSI = stoch(rsi1,rsi1,rsi1,lengthStoch)
k = sma(stochRSI,smoothK)
d = sma(k, smoothD)
plot(k, color=black)
plot(d, linewidth=2,color=purple)
hline(75, color=red)
hline(25, color=green)
```
