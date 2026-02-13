---
id: PUB;22
title: Indicator: True Strength Index
author: LazyBear
type: indicator
tags: []
boosts: 2053
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_22
---

# Description
Indicator: True Strength Index

# Source Code
```pine
//
// @author LazyBear
// @credits http://en.wikipedia.org/wiki/True_strength_index
// 
study(title = "True Strength Index [LazyBear]", shorttitle="LB_TSI", overlay=false)
r=input(25, title="Momentum Smoothing 1")
s=input(13, title="Momentum Smoothing 2")
src=close
m=src-src[1]
tsi=100*(ema(ema(m,r),s)/ema(ema(abs(m), r),s))
ul=hline(25)
ll=hline(-25)
fill(ul,ll)
plot(tsi, color=red)
```
