---
id: PUB;50
title: CCI strategy
author: HPotter
type: indicator
tags: []
boosts: 2702
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_50
---

# Description
CCI strategy

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 17/06/2014
// The Commodity Channel Index (CCI) is best used with markets that display cyclical or 
// seasonal characteristics, and is formulated to detect the beginning and ending of these 
// cycles by incorporating a moving average together with a divisor that reflects both possible 
// and actual trading ranges. The final index measures the deviation from normal, which indicates 
// major changes in market trend.
// To put it simply, the Commodity Channel Index (CCI) value shows how the instrument is trading 
// relative to its mean (average) price. When the CCI value is high, it means that the prices are 
// high compared to the average price; when the CCI value is down, it means that the prices are low 
// compared to the average price. The CCI value usually does not fall outside the -300 to 300 range 
// and, in fact, is usually in the -100 to 100 range.
////////////////////////////////////////////////////////////
study(title="CCI strategy", shorttitle="CCI strategy")
FastMA = input(10, minval=1)
SlowMA = input(20, minval=1)
hline(0, color=purple, linestyle=dashed)
xCCI = cci(close, 10)
xSMA = sma(xCCI,SlowMA)
xFMA = sma(xCCI,FastMA)
pos = iff(xSMA < xFMA , 1,
	    iff(xSMA > xFMA, -1, nz(pos[1], 0))) 
barcolor(pos == -1 ? red: pos == 1 ? green : blue)
plot(xSMA, color=red, title="CCI MA Slow")
plot(xFMA, color=blue, title="CCI MA FAST")

```
