---
id: PUB;6
title: Indicator: Market Facilitation Index [MFIndex]
author: LazyBear
type: indicator
tags: []
boosts: 2066
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_6
---

# Description
Indicator: Market Facilitation Index [MFIndex]

# Source Code
```pine
//
// @author LazyBear
// @credits http://en.wikipedia.org/wiki/Market_facilitation_index
//
// If you use this code in its original/modified form, do drop me a note. 
//
study("Market Facilitation Index [LazyBear]", shorttitle="MFIndex_LB", overlay=true)
plot_offs=input(0.005, title="Indicator offset % (below low)")
r_hl=roc((high-low)/volume,1)
r_v=roc(volume,1)
green_f= (r_hl > 0) and (r_v > 0)
fade_f=(r_hl < 0) and (r_v < 0)
fake_f=(r_hl > 0) and (r_v < 0)
squat_f=(r_hl < 0) and (r_v > 0)
b_color = green_f ? green : fade_f ? blue : fake_f ? gray : squat_f ? red : na
plot(low - (low*plot_offs), color=b_color, style=circles, linewidth=4)
```
