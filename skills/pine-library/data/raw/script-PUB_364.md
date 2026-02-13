---
id: PUB;364
title: CM_Hourly Pivots
author: ChrisMoody
type: indicator
tags: []
boosts: 2063
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_364
---

# Description
CM_Hourly Pivots

# Source Code
```pine
//created by ChrisMoody by request for pippo
//Hourly Pivots
study(title="CM_Hourly_Pivots", shorttitle="CM_Hourly_Pivots", overlay=true) 
sh = input(true, title="Show Hourly Pivots?")
sh3 = input(false, title="Show R3 & S3?")

//Classic Pivot Calculations
pivot = (high + low + close ) / 3.0 
r1 = pivot + (pivot - low)
s1 = pivot - (high - pivot) 
r2 = pivot + (high - low) 
s2 = pivot - (high - low) 
r3 = sh3 and r1 + (high - low) ? r1 + (high - low) : na
s3 = sh3 and s1 - (high - low) ? s1 - (high - low) : na
 
 //Daily Pivots 
htime_pivot = security(tickerid, '60', pivot[1]) 
htime_r1 = security(tickerid, '60', r1[1]) 
htime_s1 = security(tickerid, '60', s1[1]) 
htime_r2 = security(tickerid, '60', r2[1]) 
htime_s2 = security(tickerid, '60', s2[1])
htime_r3 = security(tickerid, '60', r3[1])
htime_s3 = security(tickerid, '60', s3[1])

plot(sh and htime_pivot ? htime_pivot : na, title="Hourly Pivot",style=circles, color=fuchsia,linewidth=3) 
plot(sh and htime_r1 ? htime_r1 : na, title="Hourly R1",style=circles, color=#DC143C,linewidth=3) 
plot(sh and htime_s1 ? htime_s1 : na, title="Hourly S1",style=circles, color=lime,linewidth=3) 
plot(sh and htime_r2 ? htime_r2 : na, title="Hourly R2",style=circles, color=maroon,linewidth=3) 
plot(sh and htime_s2 ? htime_s2 : na, title="Hourly S2",style=circles, color=#228B22,linewidth=3) 
plot(sh and htime_r3 ? htime_r3 : na, title="Hourly R3",style=circles, color=#FA8072,linewidth=3)
plot(sh and htime_s3 ? htime_s3 : na, title="Hourly S3",style=circles, color=#CD5C5C,linewidth=3)
```
