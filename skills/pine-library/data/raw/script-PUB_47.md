---
id: PUB;47
title: Enhanced Ichimoku Cloud Indicator!!!
author: ChrisMoody
type: indicator
tags: []
boosts: 2817
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_47
---

# Description
Enhanced Ichimoku Cloud Indicator!!!

# Source Code
```pine
//Created By User ChrisMoody
//Last Update 12-30-2013
//Special Thanks to Alex in Tech Support.  I spent 4 hours and couldn't get it to work and he fixed it in 2 minutes...

study(title="CM_Enhanced_Ichimoku Cloud-V3", shorttitle="CM_Enhanced_Ichimoku-V3", overlay=true)
turningPeriods = input(9, minval=1), standardPeriods = input(26, minval=1)
leadingSpan2Periods = input(52, minval=1), displacement = input(26, minval=1)
donchian(len) => avg(lowest(len), highest(len))
turning = donchian(turningPeriods)
standard = donchian(standardPeriods)
leadingSpan1 = avg(turning, standard)
leadingSpan2 = donchian(leadingSpan2Periods)
 
plot(turning, title = 'Tenkan-Sen (9 Period)', linewidth=4, color=white)
plot(standard, title = 'Kinjun-Sen (26 Period)', linewidth=4, color=orange)
plot(close, title='Chinkou Span (Lagging Line)', linewidth=4, offset = -displacement, color=aqua)
 
spanColor = leadingSpan1>=leadingSpan2 ? lime : red

p1 = plot(leadingSpan1, title = 'Senkou Span A (26 Period)', linewidth=4, offset = displacement, color=spanColor)
p2 = plot(leadingSpan2, title = 'Senkou Span B (52 Period)', linewidth=4, offset = displacement, color=spanColor)
 
fill(p1, p2, color=silver, transp=40, title='Kumo (Cloud)')

```
