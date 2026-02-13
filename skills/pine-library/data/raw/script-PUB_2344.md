---
id: PUB;2344
title: CCI with Volume Weighted EMA 
author: SpreadEagle71
type: indicator
tags: []
boosts: 1479
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2344
---

# Description
CCI with Volume Weighted EMA 

# Source Code
```pine
Title="CCI with Volume Weighted EMA"
//CCI with Volume Weighted EMA
//This indicator uses a Volume Weighted EMA which is then plugged into 
//the standard CCI(Commodity Channel Index) formula.
//By SpreadEagle71

study(title="CCI with Volume Weighted EMA ", overlay=false)
length = input(10, minval=1)
xMAVolPrice = ema(volume * close, length)
xMAVol = ema(volume, length)
src = xMAVolPrice / xMAVol

ma = sma(src, length)
cci = (src - ma) / (0.015 * dev(src, length))
plot(cci, color=black, linewidth=2)
band1 = hline(100, color=gray, linestyle=dashed)
band0 = hline(-100, color=gray, linestyle=dashed)
fill(band1, band0, color=olive)
```
