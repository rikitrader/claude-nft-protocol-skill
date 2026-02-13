---
id: PUB;62
title: Statistical Volatility - Extreme Value Method 
author: HPotter
type: indicator
tags: []
boosts: 330
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_62
---

# Description
Statistical Volatility - Extreme Value Method 

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 29/05/2014
// This indicator used to calculate the statistical volatility, sometime 
// called historical volatility, based on the Extreme Value Method.
// Please use this link to get more information about Volatility. 
////////////////////////////////////////////////////////////
study(title="Statistical Volatility - Extreme Value Method ", shorttitle="Statistical Volatility")
Length = input(30, minval=1)
xMaxC = highest(close, Length)
xMaxH = highest(high, Length)
xMinC = lowest(close, Length)
xMinL = lowest(low, Length)
SqrTime = sqrt(253 / Length)
Vol = ((0.6 * log(xMaxC / xMinC) * SqrTime) + (0.6 * log(xMaxH / xMinL) * SqrTime)) * 0.5
nRes = iff(Vol < 0,  0, iff(Vol > 2.99, 2.99, Vol))
plot(nRes, color=blue, title="Statistical Volatility")

```
