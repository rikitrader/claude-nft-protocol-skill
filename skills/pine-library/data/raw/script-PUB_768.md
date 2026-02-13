---
id: PUB;768
title: CM_Donchian Channels Modified_V2 - Alert Capable
author: ChrisMoody
type: indicator
tags: []
boosts: 3130
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_768
---

# Description
CM_Donchian Channels Modified_V2 - Alert Capable

# Source Code
```pine
//Modified Donchonian Channel with separate adjustments for upper and lower levels
//Purpose is if you expect big move up, Use lower input example 3 or 4, and longer lower input, 40 - 100 and use lower input line as a stop out
//Opposite if you expect big move down
//Mid Line Rule in Long Example.  If lower line is below entry take partial profits at Mid Line and move stop to Break even.
//If Lower line moves above entry price before price retraces to midline use Lower line as Stop...Opposite if Shorting
//Created by user ChrisMoody 1-30-2014

//Updated 12-14-2014 by ChrisMoody, Added Alert Capability, Bars Change Colors Based on Breakouts.Arrows At Bottom Showing Entry
//Create Alert by selecting Indicator, then either Alert Breakout Upside or Downside, Select Greater Than, Select Value, for Value put .99

study(title="CM_Donchian Channels Modified_V2", shorttitle="CM_DC Modified_V2", overlay=true)
length1 = input(20, minval=1, title="Upper Channel")
length2 = input(20, minval=1, title="Lower Channel")
sml = input(true, title="Show Mid-Line?")
shb = input(true, title="Show Highlight Bars When Breaking out?")
sa = input(true, title="Show Arrows on Top And Bottom of Screen When Breaking Out?")

upper = highest(length1)
lower = lowest(length2)
basis = avg(upper, lower)

break_Above = close > upper[1] ? 1 : 0
break_Below = close < lower[1] ? 1 : 0

break_AboveHB() => shb and close > upper[1] ? 1 : 0
break_BelowHB() => shb and close < lower[1] ? 1 : 0

plot(break_Above, title="Alert Breakout Upside", style=circles, linewidth=1, color=white)
plot(break_Below, title="Alert Breakout Downside", style=circles, linewidth=1, color=white)

barcolor(break_AboveHB() ?  fuchsia : na)
barcolor(break_BelowHB() ?  fuchsia : na)

plotshape(sa and break_Above ? break_Above : na, title="Arrows Showing Break Above", style=shape.triangleup, location=location.bottom, color=lime)
plotshape(sa and break_Below ? break_Below : na, title="Arrows Showing Break Above", style=shape.triangledown, location=location.top, color=red)

u = plot(upper, title="Upper DC Band", style=line, linewidth=4, color=lime)
l = plot(lower, title="Lower DC Band", style=line, linewidth=4, color=red)
plot(sml and basis ? basis : na, title="Mid-Line", color=yellow, style=line, linewidth=1)

fill(u, l, color=white, transp=75, title="Fill")
```
