---
id: PUB;15
title: Indicator: Chande's QStick Indicator
author: LazyBear
type: indicator
tags: []
boosts: 1305
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_15
---

# Description
Indicator: Chande's QStick Indicator

# Source Code
```pine
//
// @author LazyBear
// 
study(title = "Tushar Chande's QStick [LazyBear]", shorttitle="QStick_LB")
length=input(8)
hline(0)
s2=sma((close-open),length)
c_color=s2 < 0 ? (s2 < s2[1] ? red : lime) : (s2 >= 0 ? (s2 > s2[1] ? lime : red) : na)
plot(s2, color=blue, style=area)
plot(s2, color=c_color, style=circles, linewidth=3)
```
