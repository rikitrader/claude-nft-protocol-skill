---
id: PUB;2789
title: Ichimoku PanOptic TM-V1
author: BrainZZ
type: indicator
tags: []
boosts: 648
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2789
---

# Description
Ichimoku PanOptic TM-V1

# Source Code
```pine
//Created By User BrainZZ on the work of User ChrisMoody
//Last Update 15/06/2016
//new Updates include signal based on PanOptical Method by User Ichimoku_Trader

study(title="Ichimoku PanOptic TM-V1", shorttitle="PTM_Ichimoku-V1", overlay=true)
turningPeriods = input(9, minval=1, title="Tenkan-Sen")
standardPeriods = input(26, minval=1, title="Kinjun-Sen")
leadingSpan2Periods = input(52, minval=1, title="Senkou Span B")
displacement = input(26, minval=1, title="-ChinkouSpan/+SenkouSpan A")
sts = input(true, title="Show TS (Tenkan-Sen)?")
sks = input(true, title="Show KS (Kinjun-Sen)?")
sll = input(true, title="Show CS (ChinkouSpan)?")
sc = input(true, title="Show Kumo Cloud?")
cr1 = input(false, title="Show Crosses up/down of TS and KS?")
cr2 = input(false, title="Show turning up/down of KS?")

//Definitions for Tenkan-Sen (9 Period), Kinjun-Sen (26 Period), Chinkou Span (Lagging Line)
donchian(len) => avg(lowest(len), highest(len))
turning = donchian(turningPeriods)
standard = donchian(standardPeriods)
leadingSpan1 = avg(turning, standard)
leadingSpan2 = donchian(leadingSpan2Periods)

//Crosses up/down Tenkan-Sen (9 Period) and Kinjun-Sen (26 Period)
crossUpTenkanKinjun = turning[1] < standard[1] and turning > standard ? 1 : 0
crossDnTenkanKinjun = turning[1] > standard[1] and turning < standard ? 1 : 0
cupA = crossUpTenkanKinjun == 1 ? crossUpTenkanKinjun : 0
cdnB = crossDnTenkanKinjun == 1 ? crossDnTenkanKinjun : 0

//Changing in KS as trend signal
KSturnup = standard[1]<standard and standard[2]>=standard[1] ? 1 : 0
KSturndown = standard[1]>standard and standard[2]<=standard[1] ? 1 : 0
InversionUP = standard[9] >= standard[1] and KSturnup == 1 ? 1 : 0
InversionDOWN = standard[9] <= standard[1] and KSturndown == 1 ? 1 : 0
KupA = KSturnup == 1 and InversionUP == 1 ? KSturnup : 0
KdnB = KSturndown == 1 and InversionDOWN == 1 ? KSturndown : 0

//First Definition for Ability to Color Cloud based on Trend.
leadingSpan1Above = leadingSpan1 >= leadingSpan2 ? 1 : na
leadingSpan2Below = leadingSpan1 <= leadingSpan2 ? 1 : na
//Next 4 lines are code used as plots in order to Color Cloud based on Trend
span1plotU = leadingSpan1Above ? leadingSpan1 : na
span2plotU = leadingSpan1Above ? leadingSpan2 : na

span1plotD = leadingSpan2Below ? leadingSpan1 : na
span2plotD = leadingSpan2Below ? leadingSpan2 : na

col = leadingSpan1 >= leadingSpan2 ? green : red

//plots for 3 lines other than cloud.
plot(sts and turning ? turning : na, title = 'Tenkan-Sen (9 Period)', linewidth=3, color=orange)
plot(sks and standard ? standard : na, title = 'Kinjun-Sen (26 Period)', linewidth=3, color=red)
plot(sll and close ? close : na, title='Chinkou Span (Lagging Line)', linewidth=1, offset = -displacement, color=navy)
//Cloud Lines Plot Statements - ***Regular Lines to Fill in Break in Gap
plot(sc and leadingSpan1 ? leadingSpan1 : na, title = 'Senkou Span A (26 Period) Cloud', style=line, linewidth=1, offset = displacement, color=col)
plot(sc and leadingSpan2 ? leadingSpan2 : na, title = 'Senkou Span B (52 Period) Cloud', style=line, linewidth=1, offset = displacement, color=col)
//Cloud Lines Plot Statements - ***linebr to create rules for change in Shading
p1 = plot(sc and span1plotU ? span1plotU  : na, title = 'Senkou Span A (26 Period) Above Span B Cloud', style=linebr, linewidth=1, offset = displacement, color=col)
p2 = plot(sc and span2plotU ? span2plotU  : na, title = 'Senkou Span B (52 Period) Below Span A Cloud', style=linebr, linewidth=1, offset = displacement, color=col)
p3 = plot(sc and span1plotD ? span1plotD  : na, title = 'Senkou Span A (26 Period) Below Span B Cloud', style=linebr, linewidth=1, offset = displacement, color=col)
p4 = plot(sc and span2plotD ? span2plotD  : na, title = 'Senkou Span B (52 Period) Above Span A Cloud', style=linebr, linewidth=1, offset = displacement, color=col)
//Fills that color cloud based on Trend.
fill(p1, p2, color=green, transp=70, title='Kumo (Cloud)')
fill(p3, p4, color=red, transp=70, title='Kumo (Cloud)')

//Arrow Plots At TS KS cross
plotshape(cr1 and cupA ? cupA : na, title="CrossUp TS/KS Entry Arrow", style=shape.triangleup,location=location.belowbar, color=green, transp=0, size=size.tiny)
plotshape(cr1 and cdnB*-1 ? cdnB*-1 : na, title="CrossDn TS/KS Entry Arrow", style=shape.triangledown,location=location.abovebar, color=red, transp=0, size=size.tiny)

//Arrow plot on KS turn
plotshape(cr2 and KupA ? KupA : na, title="CrossUp TS/KS Entry Arrow", style=shape.triangleup,location=location.bottom, color=green, transp=0, size=size.tiny)
plotshape(cr2 and KdnB*-1 ? KdnB*-1 : na, title="CrossDn TS/KS Entry Arrow", style=shape.triangledown,location=location.top, color=red, transp=0, size=size.tiny)

```
