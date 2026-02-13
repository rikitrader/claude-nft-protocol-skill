---
id: PUB;5
title: Indicator: Volatility Quality Index [VQI]
author: LazyBear
type: indicator
tags: []
boosts: 1711
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_5
---

# Description
Indicator: Volatility Quality Index [VQI]

# Source Code
```pine
//
// @author LazyBear
// @credits Thomas Stridsman - http://www.3pips.com/volatility-quality-index-vq/
// If you use this code in its original/modified form, do drop me a note. 
//
study("Volatility Quality Index [LazyBear]", shorttitle="VQI_LB")
length_slow=input(9, title="Fast EMA Length")
length_fast=input(200, title="Slow EMA Length")
vqi_t=iff((tr != 0) and ((high - low) != 0) ,(((close-close[1])/tr)+((close-open)/(high-low)))*0.5,nz(vqi_t[1]))
vqi = abs(vqi_t) * ((close - close[1] + (close - open)) * 0.5)
vqi_sum=cum(vqi)
plot(vqi_sum, color=red, linewidth=2)
plot(sma(vqi_sum,length_slow), color=green, linewidth=2)
plot(sma(vqi_sum,length_fast),color=orange, linewidth=2)

```
