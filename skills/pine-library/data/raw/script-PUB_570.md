---
id: PUB;570
title: Hammer, Hanging man, Shooting star, Inverted hammer Indicators
author: DovCaspi
type: indicator
tags: []
boosts: 2944
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_570
---

# Description
Hammer, Hanging man, Shooting star, Inverted hammer Indicators

# Source Code
```pine
study("Hammer and Hanging man", overlay=true)

high_h = high[1]
low_h = low[1]
open_h = open[1]
close_h = close[1]

shadow_h = high_h - low_h
body_h = abs(open_h - close_h)
bodyMid_h = 0.5 * (open_h + close_h) - low_h


shadow = high - low
body = abs(open - close)
bodyMid = 0.5 * (open + close) - low
bodyRed = open > close and body > (0.3 * shadow)
bodyGreen = close > open and body > (0.3 * shadow)

bodyTop =  bodyMid_h > (0.7 * shadow_h)
bodyBottom =  bodyMid_h < (0.3 * shadow_h)
hammerShape = body_h < (0.5 * shadow_h)

hangingMan = bodyRed and hammerShape and bodyTop ? high_h : na
hammer = bodyGreen and hammerShape and bodyTop ? high_h : na

shootingStar = bodyRed and hammerShape and bodyBottom ? low_h : na
invertedHammer = bodyGreen and hammerShape and bodyBottom ? low_h : na

plot( hangingMan  , title="Hanging man", style=cross, linewidth=10,color=red, transp=95, offset = -1)
plot( hammer  , title="Hammer", style=circles, linewidth=10,color=green, transp=95, offset = -1)


plot( shootingStar  , title="Shooting star", style=cross, linewidth=10,color=red, transp=95, offset = -1)
plot( invertedHammer  , title="Inverted hammer", style=circles, linewidth=10,color=green, transp=95, offset = -1)

```
