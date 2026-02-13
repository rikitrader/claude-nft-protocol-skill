---
id: PUB;2557
title: Daily Pivots
author: Tass
type: indicator
tags: []
boosts: 767
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2557
---

# Description
Daily Pivots

# Source Code
```pine
//created by PGT4
//Daily Pivots
study(title="Daily Pivots", shorttitle="daily_pivots", overlay=true) 
sh = input(true, title="Show Daily Pivots?")
sh1 = input(false, title="Show R1 & S1?")
sh2 = input(false, title="Show R2 & S2?")
sh3 = input(false, title="Show R3 & S3?")

//Classic Pivot Calculations
pivot = (high + low + close ) / 3.0 
r1 = sh1 ? pivot + (pivot - low) : na
s1 = sh1 ? pivot - (high - pivot) : na
r2 = sh2 ? pivot + (high - low) : na
s2 = sh2 ? pivot - (high - low) : na 
r3 = sh3 and r1 + (high - low) ? r1 + (high - low) : na
s3 = sh3 and s1 - (high - low) ? s1 - (high - low) : na
 
 //Daily Pivots 
htime_pivot = security(tickerid, '1440', pivot[1]) 
htime_r1 = security(tickerid, '1440', r1[1]) 
htime_s1 = security(tickerid, '1440', s1[1]) 
htime_r2 = security(tickerid, '1440', r2[1]) 
htime_s2 = security(tickerid, '1440', s2[1])
htime_r3 = security(tickerid, '1440', r3[1])
htime_s3 = security(tickerid, '1440', s3[1])

plot(sh and htime_pivot ? htime_pivot : na, title="Daily Pivot",style=cross, color=blue,linewidth=3) 
plot(sh and htime_r1 ? htime_r1 : na, title="Daily R1",style=cross, color=#DC143C,linewidth=3) 
plot(sh and htime_s1 ? htime_s1 : na, title="Daily S1",style=cross, color=lime,linewidth=3) 
plot(sh and htime_r2 ? htime_r2 : na, title="Daily R2",style=cross, color=maroon,linewidth=3) 
plot(sh and htime_s2 ? htime_s2 : na, title="Daily S2",style=cross, color=#228B22,linewidth=3) 
plot(sh and htime_r3 ? htime_r3 : na, title="Daily R3",style=cross, color=#FA8072,linewidth=3)
plot(sh and htime_s3 ? htime_s3 : na, title="Daily S3",style=cross, color=#CD5C5C,linewidth=3)
```
