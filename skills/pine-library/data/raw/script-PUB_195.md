---
id: PUB;195
title: 2/20 Exponential Moving Average
author: HPotter
type: indicator
tags: []
boosts: 960
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_195
---

# Description
2/20 Exponential Moving Average

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 15/07/2014
// This indicator plots 2/20 exponential moving average. For the Mov 
// Avg X 2/20 Indicator, the EMA bar will be painted when the Alert criteria is met.
////////////////////////////////////////////////////////////
study(title="Strategy 2/20 Exponential Moving Average", overlay = true)
Length = input(20, minval=1)
xPrice = close
xXA = ema(xPrice, Length)
nHH = max(high, high[1])
nLL = min(low, low[1])
nXS = iff((nLL > xXA)or(nHH < xXA), nLL, nHH)
plot(nXS, color=blue, title="XAverage")

```
