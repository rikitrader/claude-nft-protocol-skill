---
id: PUB;408
title: Indicator: Forecast Oscillator & a BB extrapolation experiment
author: LazyBear
type: indicator
tags: []
boosts: 815
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_408
---

# Description
Indicator: Forecast Oscillator & a BB extrapolation experiment

# Source Code
```pine
//
// @author LazyBear
// 
study(title = "Forecast Oscillator [LazyBear]", shorttitle="ForecastOsc_LB")
pf=100*((close[0]-close[1])/close[0])
//plot(pf, color=green)
plot(sma(pf,3), color=orange)
hline(0)
```
