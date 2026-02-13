---
id: PUB;2465
title: Inside Bar Breakout Failure
author: FxLowe
type: indicator
tags: []
boosts: 513
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2465
---

# Description
Inside Bar Breakout Failure

# Source Code
```pine
//FxLowe - Inside bar breakout failure.

study(title = "Inside Bar Breakout Failure", overlay = true)

outsidebar = (high >= high[1] and low <= low[1])
insidebar = ((high[1] <= high[2] and low[1] >= low[2]) and not(outsidebar))

bearishibbf=( insidebar and (high > high[1] and close < high[1]))
barcolor( bearishibbf ? white : na, 0, true, "Bearish Inside Bar Breakout Failure")
plotshape(bearishibbf, title= "Bearish Inside Bar Breakout Failure", location=location.abovebar, color=white, style=shape.arrowdown, text="Inside Bar\nBreakout Failure")

bullishibbf=(insidebar and (low < low[1] and close > low[1]))
barcolor( bullishibbf ? white : na, 0, true, "Bullish Inside Bar Breakout Failure")
plotshape(bullishibbf, title= "Bullish Inside Bar Breakout Failure", location=location.belowbar, color=white, style=shape.arrowup, text="Inside Bar\nBreakout Failure")
```
