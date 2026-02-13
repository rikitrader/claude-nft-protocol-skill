---
id: PUB;14
title: Indicator: ElliotWave Oscillator [EWO]
author: LazyBear
type: indicator
tags: []
boosts: 11350
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_14
---

# Description
Indicator: ElliotWave Oscillator [EWO]

# Source Code
```pine
//
// @author LazyBear
//
study(title = "Elliot Wave Oscillator [LazyBear]", shorttitle="EWO_LB")
s2=ema(close, 5) - ema(close, 35)
c_color=s2 <= 0 ? red : lime
plot(s2, color=c_color, style=histogram, linewidth=2)
```
