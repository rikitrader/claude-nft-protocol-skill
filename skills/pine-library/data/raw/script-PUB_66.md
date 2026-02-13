---
id: PUB;66
title: Relative Volatility Index 
author: HPotter
type: indicator
tags: []
boosts: 553
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_66
---

# Description
Relative Volatility Index 

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 27/05/2014
// The RVI is a modified form of the relative strength index (RSI). 
// The original RSI calculation separates one-day net changes into 
// positive closes and negative closes, then smoothes the data and 
// normalizes the ratio on a scale of zero to 100 as the basis for the 
// formula. The RVI uses the same basic formula but substitutes the 
// 10-day standard deviation of the closing prices for either the up 
// close or the down close. The goal is to create an indicator that 
// measures the general direction of volatility. The volatility is 
// being measured by the 10-days standard deviation of the closing prices. 
////////////////////////////////////////////////////////////
study(title="Relative Volatility Index", shorttitle="RVI")
Period = input(10, minval=1)
hline(0, color=purple, linestyle=dashed)
hline(20, color=red, linestyle=line)
hline(80, color=green, linestyle=line)
xPrice = close
StdDev = stdev(xPrice, Period)
d = iff(close > close[1], 0, StdDev)
u = iff(close > close[1], StdDev, 0)
nU = (13 * nz(nU[1],0) + u) / 14
nD = (13 * nz(nD[1],0) + d) / 14
nRes = 100 * nU / (nU + nD)
plot(nRes, color=red, title="RVI")

```
