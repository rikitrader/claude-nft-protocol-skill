---
id: PUB;24
title: Indicator: Zero Lag EMA & a simple trading strategy
author: LazyBear
type: indicator
tags: []
boosts: 5966
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_24
---

# Description
Indicator: Zero Lag EMA & a simple trading strategy

# Source Code
```pine
//
// @author LazyBear
//
study(title = "Almost Zero Lag EMA [LazyBear]", shorttitle="ZeroLagEMA_LB", overlay=true)
length=input(10)
src=close
ema1=ema(src, length)
ema2=ema(ema1, length)
d=ema1-ema2
zlema=ema1+d
plot(zlema)
```
