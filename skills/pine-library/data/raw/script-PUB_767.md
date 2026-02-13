---
id: PUB;767
title: CM_Donchian Channels Modified_V2_Lower_Alert
author: ChrisMoody
type: indicator
tags: []
boosts: 1418
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_767
---

# Description
CM_Donchian Channels Modified_V2_Lower_Alert

# Source Code
```pine
//Created By ChrisMoody on 12-14-2014 to Set Alerts for CM_Donchonian Channels Modified_V2
//Create Alert by selecting Indicator, then either Alert Breakout Upside or Downside, Select Greater Than, Select Value, for Value put .99

study(title="CM_Donchian Channels Modified_V2_Lower_Alert", shorttitle="CM_DC Modified_V2_Lower_Alert", overlay=false)

length1 = input(20, minval=1, title="Upper Channel")
length2 = input(20, minval=1, title="Lower Channel")

upper = highest(length1)
lower = lowest(length2)

basis = avg(upper, lower)

break_Above = close > upper[1] ? 1 : 0
break_Below = close < lower[1] ? 1 : 0

plot(break_Above, title="Alert Breakout Upside", style=line, linewidth=2, color=lime)
plot(break_Below, title="Alert Breakout Downside", style=line, linewidth=2, color=red)
```
