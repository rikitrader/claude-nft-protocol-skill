---
id: PUB;87
title: Detrended Price Oscillator
author: HPotter
type: indicator
tags: []
boosts: 671
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_87
---

# Description
Detrended Price Oscillator

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 22/04/2014
// The Detrend Price Osc indicator is similar to a moving average, 
// in that it filters out trends in prices to more easily identify 
// cycles. The indicator is an attempt to define cycles in a trend 
// by drawing a moving average as a horizontal straight line and 
// placing prices along the line according to their relation to a 
// moving average. It provides a means of identifying underlying 
// cycles not apparent when the moving average is viewed within a 
// price chart. Cycles of a longer duration than the Length (number 
// of bars used to calculate the Detrend Price Osc) are effectively 
// filtered or removed by the oscillator.
////////////////////////////////////////////////////////////
study(title="Detrended Price Oscillator", shorttitle="DPO")
Length = input(14, minval=1)
Series = input(title="Price", type=string, defval="close")
hline(0, color=green, linestyle=line)
xPrice = close
xsma = sma(xPrice, Length)
nRes = xPrice - xsma
plot(nRes, color=red, title="Detrended Price Oscillator")

```
