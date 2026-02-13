---
id: PUB;65
title: Volatility 
author: HPotter
type: indicator
tags: []
boosts: 1578
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_65
---

# Description
Volatility 

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 29/05/2014
// The Volatility function measures the market volatility by plotting a 
// smoothed average of the True Range. It returns an average of the TrueRange 
// over a specific number of bars, giving higher weight to the TrueRange of 
// the most recent bar.
////////////////////////////////////////////////////////////
study(title="Volatility", shorttitle="Volatility")
Length = input(10, minval=1)
xATR = atr(Length)
nRes = ((Length - 1) * nz(nRes[1], 0) + xATR) / Length
plot(nRes, color=blue, title="Volatility")

```
