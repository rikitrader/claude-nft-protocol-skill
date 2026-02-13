---
id: PUB;1184
title: GRaB Candles by mattlacoco with MMM by Harold_NL V1.1
author: UnknownUnicorn117262
type: indicator
tags: []
boosts: 648
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1184
---

# Description
GRaB Candles by mattlacoco with MMM by Harold_NL V1.1

# Source Code
```pine
study(title='Buy green Sell Red', shorttitle='BGSR', overlay=true)
// V1.1 Adjusting colors to GRaB originals Green, Red and Blue.
// Introducing a color for neutral.

// plot midline from Murrey Math for trifecta entry and exit
// Inputs
length = input(100, minval = 10, title = "Murrey: Look back Length")
showmidline = input(true, title = "Murrey: plot midline")
showrange = input(true, title = "Murrey: plot range")

// begin MMM line
hi = highest(high, length)
lo = lowest(low, length)
range = hi - lo
midline = lo + range / 2

//plot (midline, color = black)
//showmidline == true ? plot (midline, color = black) : na
//showrange ? plot (range, color = orange) : na

plotmidline = showmidline == true ? midline : na
plotrange = showrange == true ? lo : na

plot(plotmidline, title="Murrey Math Midline",color=black) 
plot(plotrange, title="Murrey Math Range low",color=fuchsia)
plot(plotrange + range, title="Murrey Math Range high",color=fuchsia)
// end MMM line

// vars
emaPeriod = input(title="GRaB: EMA Period", type=integer, defval=34)
showWave = input(title="GRaB: Show Wave", type=bool, defval=false)

// build wave
emaHigh = ema(high,emaPeriod)
emaLow = ema(low,emaPeriod)
emaClose = ema(close,emaPeriod)

waveHigh = showWave == true ? emaHigh : na
waveLow = showWave == true ? emaLow : na
waveClose = showWave == true ? emaClose : na

plot(waveHigh, title="EMA High",color=red )
plot(waveLow, title="EMA Low", color=green)
plot(waveClose, title="EMA Close", color=silver)

// paint GRaB candles according to close position relative to wave
barcolor(close < emaLow ? close > open ? red : maroon : close > emaHigh ? close > open ? lime : green: close > open ? silver : gray)

```
