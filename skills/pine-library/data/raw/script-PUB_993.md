---
id: PUB;993
title: GRaB Candles
author: mattlacoco
type: indicator
tags: []
boosts: 1483
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_993
---

# Description
GRaB Candles

# Source Code
```pine
study(title='Buy Blue Sell Red', shorttitle='BBSR', overlay=true)
// vars
emaPeriod = input(title="EMA Period", type=integer, defval=34)
showWave = input(title="Show Wave", type=bool, defval=false)

// build wave
emaHigh = ema(high,emaPeriod)
emaLow = ema(low,emaPeriod)
emaClose = ema(close,emaPeriod)

waveHigh = showWave == true ? emaHigh : na
waveLow = showWave == true ? emaLow : na
waveClose = showWave == true ? emaClose : na

plot(waveHigh, title="EMA High",color=red )
plot(waveLow, title="EMA Low", color=blue)
plot(waveClose, title="EMA Close", color=silver)

// paint candles according to close position relative to wave
barcolor(close < emaLow ? close > open ? red : maroon : close > emaHigh ? close > open ? blue : navy : close > open ? silver : gray)

```
