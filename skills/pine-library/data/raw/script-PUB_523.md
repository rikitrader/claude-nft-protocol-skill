---
id: PUB;523
title: Breakout Range Short Strategy
author: HPotter
type: indicator
tags: []
boosts: 949
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_523
---

# Description
Breakout Range Short Strategy

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 09/09/2014
// Breakout Range Short Strategy
////////////////////////////////////////////////////////////
study(title="Breakout Range Short Strategy", overlay = true)
look_bak = input(4, minval=1, title="Look Bak")
xLowest = lowest(low, look_bak)
pos =	iff(low < xLowest[1], 1, 0) 
barcolor(pos == 1 ? red: blue )
plotshape(pos, style=shape.triangledown, location = location.abovebar, color = red)
```
