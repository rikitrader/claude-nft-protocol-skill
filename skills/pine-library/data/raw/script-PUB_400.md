---
id: PUB;400
title: Enhanced Index [LazyBear]
author: LazyBear
type: indicator
tags: []
boosts: 366
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_400
---

# Description
Enhanced Index [LazyBear]

# Source Code
```pine
//
// @author LazyBear 
// List of all my indicators: https://www.tradingview.com/v/4IneGo8h/
//
study("Enhanced Index [LazyBear]", shorttitle="EIDX_LB")
src=close
length=input(14)
lengthMA=input(8)
dnm=(highest(src, length) - lowest(src, length))
closewr=2*(src-sma(src, round(length/2)))/dnm
ul=hline(1, color=red), ll=hline(-1, color=green), hline(0)
fill(ul,ll)
plot(closewr, color=green, linewidth=1)
plot(ema(closewr, lengthMA), color=red)
```
