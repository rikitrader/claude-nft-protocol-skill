---
id: PUB;1216
title: Fisher Transform of On Balance Volume (by ChartArt)
author: ChartArt
type: indicator
tags: []
boosts: 1305
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1216
---

# Description
Fisher Transform of On Balance Volume (by ChartArt)

# Source Code
```pine
study(title="Fisher Transform of On Balance Volume", shorttitle="CA_-_Fisher_of_OBV")

// version 1.0
// idea by ChartArt on April 8, 2015
// using TradingView indicators 'Fisher Transform' and 'On Balance Volume'
// (this indicator only works with symbols where volume data is available)
// list of my work: 
// https://www.tradingview.com/u/ChartArt/

//On Balance Volume
src = close
obv = cum(change(src) > 0 ? volume : change(src) < 0 ? -volume : 0*volume)

//Fisher Transform of OBV
len = input(12, minval=2, title="Period of Fisher Transform of OBV")
high_ = highest(obv, len)
low_ = lowest(obv, len)
round_(val) => val > .99 ? .999 : val < -.99 ? -.999 : val
value = round_(.66 * ((obv - low_) / max(high_ - low_, .001) - .5) + .67 * nz(value[1]))
fish1 = .5 * log((1 + value) / max(1 - value, .001)) + .5 * nz(fish1[1])
signallen = input(12, title="Linear Regression Signal Line Period")
signal = linreg(fish1,signallen,0)

fish2 = fish1[1]
plot(fish2, color=silver, title="Fast Signal Line")
plot(fish1, color=blue, title="Fisher Transform of OBV")
plot(signal,color=red, title="Linear Regression Signal Line")
hline(0, color=maroon)
```
