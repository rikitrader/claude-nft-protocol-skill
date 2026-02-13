---
id: PUB;1333
title: Baseline_VX1  &  Strategy 
author: vdubus
type: indicator
tags: []
boosts: 1387
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1333
---

# Description
Baseline_VX1  &  Strategy 

# Source Code
```pine
study(title="Baseline_VX1", shorttitle="Baseline_VX1", overlay=false)
shrt = sma(close, 3)
lng = sma(close, 13)
plot(shrt, color=blue, linewidth=2)
plot(lng, color=red, linewidth=4)
plot(cross(lng, shrt) ? lng : na, style = circles, linewidth = 4)
OutputSignal = lng >= shrt ? 1 : 0
bgcolor(OutputSignal>0?#000000:#128E89, transp=70)
//==============================================
//plot(sma(m1_src, m1_p), color=red, linewidth=2, title="MA1")

```
