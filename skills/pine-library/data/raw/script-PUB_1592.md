---
id: PUB;1592
title: Pivot Range Pivot Boss
author: cristian.d
type: indicator
tags: []
boosts: 4421
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1592
---

# Description
Pivot Range Pivot Boss

# Source Code
```pine
//Created by CristianD
study(title="Pivot Range", shorttitle="CD_PivotR", overlay=true) 
sd = input(true, title="Show Daily Pivots?")

//Pivot Range Calculations - Mark Fisher
pivot = (high + low + close ) / 3.0 
bc = (high + low ) / 2.0 
tc = (pivot - bc) + pivot

//Daily Pivot Range 
dtime_pivot = security(tickerid, 'D', pivot[1]) 
dtime_bc = security(tickerid, 'D', bc[1]) 
dtime_tc = security(tickerid, 'D', tc[1]) 

offs_daily = 0 
plot(sd and dtime_pivot ? dtime_pivot : na, title="Daily Pivot",style=circles, color=fuchsia,linewidth=3) 
plot(sd and dtime_bc ? dtime_bc : na, title="Daily BC",style=circles, color=blue,linewidth=3)
plot(sd and dtime_tc ? dtime_tc : na, title="Daily TC",style=circles, color=blue,linewidth=3)

```
