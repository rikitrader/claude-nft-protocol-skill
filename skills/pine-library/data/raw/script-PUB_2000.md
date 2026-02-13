---
id: PUB;2000
title:  ST15 CM inspired 4hr renko Pivots
author: stocktrader15
type: indicator
tags: []
boosts: 434
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2000
---

# Description
 ST15 CM inspired 4hr renko Pivots

# Source Code
```pine
study(title=" ST15 CM inspired 4hr renko Pivots", shorttitle="4hr RP V1", overlay=true) 
sh = input(true, title="Show 4 Hour Pivots?")
sh3 = input(false, title="Show R3 & S3?")


pivot = (high + low + close ) / 3.0 
r1 = pivot + (pivot - low)
s1 = pivot - (high - pivot) 
r2 = pivot + (high - low) 
s2 = pivot - (high - low) 
r3 = sh3 and r1 + (high - low) ? r1 + (high - low) : na
s3 = sh3 and s1 - (high - low) ? s1 - (high - low) : na
 
 //Daily Pivots 
htime_pivot = security(tickerid, '240', pivot[1]) 
htime_r1 = security(tickerid, '240', r1[1]) 
htime_s1 = security(tickerid, '240', s1[1]) 
htime_r2 = security(tickerid, '240', r2[1]) 
htime_s2 = security(tickerid, '240', s2[1])
htime_r3 = security(tickerid, '240', r3[1])
htime_s3 = security(tickerid, '240', s3[1])

plot(sh and htime_pivot ? htime_pivot : na, title="4 Hour Pivot",style=circles, color=fuchsia,linewidth=3) 
plot(sh and htime_r1 ? htime_r1 : na, title="R1",style=circles, color=#DC143C,linewidth=3) 
plot(sh and htime_s1 ? htime_s1 : na, title="S1",style=circles, color=lime,linewidth=3) 
plot(sh and htime_r2 ? htime_r2 : na, title="R2",style=circles, color=maroon,linewidth=3) 
plot(sh and htime_s2 ? htime_s2 : na, title="S2",style=circles, color=#228B22,linewidth=3) 
plot(sh and htime_r3 ? htime_r3 : na, title="R3",style=circles, color=#FA8072,linewidth=3)
plot(sh and htime_s3 ? htime_s3 : na, title="S3",style=circles, color=#CD5C5C,linewidth=3)
```
