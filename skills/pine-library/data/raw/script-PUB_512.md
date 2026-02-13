---
id: PUB;512
title: Smoothed RSI
author: HPotter
type: indicator
tags: []
boosts: 1237
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_512
---

# Description
Smoothed RSI

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 03/09/2014
// This is new version of RSI oscillator indicator, developed by John Ehlers. 
// The main advantage of his way of enhancing the RSI indicator is smoothing 
// with minimum of lag penalty. 
////////////////////////////////////////////////////////////
study(title="Smoothed RSI")
Length = input(10, minval=1)
xValue = (close + 2 * close[1] + 2 * close[2] + close[3] ) / 6
CU23 = sum(iff(xValue > xValue[1], xValue - xValue[1], 0), Length)
CD23 = sum(iff(xValue < xValue[1], xValue[1] - xValue, 0), Length)
nRes = iff(CU23 + CD23 != 0, CU23/(CU23 + CD23), 0)
plot(nRes, color=blue, title="Smoothed RSI")
```
