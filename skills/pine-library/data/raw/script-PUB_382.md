---
id: PUB;382
title: CM Enhanced Ichimoku Cloud-V4
author: ChrisMoody
type: indicator
tags: []
boosts: 1339
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_382
---

# Description
CM Enhanced Ichimoku Cloud-V4

# Source Code
```pine
//Created By User ChrisMoody Last Update 8/10/14
//Ability to Turn On/Off Cloud Color Based on Trend
//Updated Correct Plot Names for Alerts

study(title="CM_Enhanced_Ichimoku Cloud-V4", shorttitle="CM_Enhanced_Ichimoku-V4", overlay=true)
turningPeriods = input(9, minval=1, title="Tenkan-Sen")
standardPeriods = input(26, minval=1, title="Kinjun-Sen")
leadingSpan2Periods = input(52, minval=1, title="Senkou Span B")
displacement = input(26, minval=1, title="-ChinkouSpan/+SenkouSpan A")
scc = input(true, title="Show Cloud Color Change Based on Trend?")

donchian(len) => avg(lowest(len), highest(len))
turning = donchian(turningPeriods)
standard = donchian(standardPeriods)
leadingSpan1 = avg(turning, standard)
leadingSpan2 = donchian(leadingSpan2Periods)
 
plot(turning, title = 'Tenkan-Sen (9 Period)', linewidth=4, color=#FF001A)
plot(standard, title = 'Kinjun-Sen (26 Period)', linewidth=4, color=lime)
plot(close, title='Chinkou Span (Lagging Line)', linewidth=4, offset = -displacement, color=silver)
 
spanColor = scc and leadingSpan1 >= leadingSpan2 ? green: scc and leadingSpan1 < leadingSpan2 ? red : yellow

p1 = plot(leadingSpan1, title = 'Senkou Span A (26 Period) Cloud', style=linebr, linewidth=6, offset = displacement, color=spanColor)
p2 = plot(leadingSpan2, title = 'Senkou Span B (52 Period) Cloud', style=linebr, linewidth=6, offset = displacement, color=spanColor)

fill(p1, p2, color=silver, transp=40, title='Kumo (Cloud)')


```
