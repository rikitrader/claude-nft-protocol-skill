---
id: PUB;20
title: Indicator: Balance Of Power
author: LazyBear
type: indicator
tags: []
boosts: 1086
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_20
---

# Description
Indicator: Balance Of Power

# Source Code
```pine
//
// @author LazyBear
//
// Balance Of Power - BOP
//
study(title = "Balance of Power [LazyBear]",shorttitle="BOP_LB")
PlotEMA=input(true, "Plot SMA?", type=bool)
PlotOuterLine=input(false, "Plot Outer line?", type=bool )
length=input(14, title="MA length")
BOP=(close - open) / (high - low)
b_color=(BOP>=0 ? (BOP>=BOP[1] ? green : orange) : (BOP>=BOP[1] ? orange : red))
hline(0)
plot(BOP, color=b_color, style=columns, linewidth=3)
plot(PlotOuterLine?BOP:na, color=gray, style=line, linewidth=2)
plot(PlotEMA?sma(BOP, length):na, color=navy, linewidth=2)

```
