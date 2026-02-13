---
id: PUB;1332
title: MACD_VXI
author: vdubus
type: indicator
tags: []
boosts: 11242
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1332
---

# Description
MACD_VXI

# Source Code
```pine
study(title="MACD_VXI", shorttitle="MACD_VXI")
source = close
fastLength = input(13, minval=1), slowLength=input(21,minval=1)
signalLength=input(8,minval=1)
fastMA = ema(source, fastLength)
slowMA = ema(source, slowLength)
macd = fastMA - slowMA
signal = sma(macd, signalLength)
hist = macd - signal
plot(hist, style=histogram, color=black, linewidth=1)
plot(macd, color=red, linewidth=1)
plot(signal, color=blue, linewidth=2)
//----------------
plot(cross(signal, macd) ? signal : na, color=black, style = circles, linewidth = 4)
OutputSignal = signal >= macd ? 1 : 0
bgcolor(OutputSignal>0?#000000:#128E89, transp=80)
//===============================================
```
