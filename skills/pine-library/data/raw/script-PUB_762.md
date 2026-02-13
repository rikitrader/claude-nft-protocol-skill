---
id: PUB;762
title: TDMacd
author: ChaosTrader
type: indicator
tags: []
boosts: 5239
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_762
---

# Description
TDMacd

# Source Code
```pine
study(title="TDMacd", shorttitle="MACD")
source = close
fastLength = input(5, minval=1), slowLength=input(20,minval=1)
signalLength=input(30,minval=1)
fastMA = ema(source, fastLength)
slowMA = ema(source, slowLength)
macd = fastMA - slowMA
signal = sma(macd, signalLength)
plot(macd, color = change(macd) <= 0 ? red : lime, style=histogram) 
plot(macd, color=black,style=line)
plot(signal, color=change(signal) <= 0 ? red : green, style=line)
```
