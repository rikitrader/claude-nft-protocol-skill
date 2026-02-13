---
id: PUB;522
title: Breakout Range Long Strategy
author: HPotter
type: indicator
tags: []
boosts: 1203
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_522
---

# Description
Breakout Range Long Strategy

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 09/09/2014
// Breakout Range Long Strategy
////////////////////////////////////////////////////////////
study(title="Breakout Range Long Strategy", overlay = true)
look_bak = input(4, minval=1, title="Look Bak")
xHighest = highest(high, look_bak)
pos =	iff(high > xHighest[1], 1, 0) 
barcolor(pos == 1 ? green: blue )
plotshape(pos, style=shape.triangleup, location = location.belowbar, color = green)
```
