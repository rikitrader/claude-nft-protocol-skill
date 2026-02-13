---
id: PUB;43
title: New Indicator!!! Opening Range_V1
author: ChrisMoody
type: indicator
tags: []
boosts: 2607
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_43
---

# Description
New Indicator!!! Opening Range_V1

# Source Code
```pine
//Created by user ChrisMoody, with help from Alex in TechSupport and TheLark
//Currently works on Stocks
//Currently works on Forex but only based on the New York Session starting at 1700 East Coast Time
//Futurer Versions will have options to plot sessions bsed on Forex Europe Opening Range , Asia, etc.
study(title="CM_Opening-Range-V1", shorttitle="CM_OpenRnge-V1", overlay=true)
up60on = input(true, title="60 Minute Opening Range High")
down60on = input(true, title="60 Minute Opening Range Low")
up30on = input(false, title="30 Minute Opening Range High")
down30on = input(false, title="30 Minute Opening Range Low")

is_newbar(res) => change(time(res)) != 0 

adopt(r, s) => security(tickerid, r, s) 

high_range = valuewhen(is_newbar('D'),high,0)
low_range = valuewhen(is_newbar('D'),low,0)

high_rangeL = valuewhen(is_newbar('D'),high,0) 
low_rangeL = valuewhen(is_newbar('D'),low,0) 

up = plot(up60on ? adopt('60', high_range):na, color = lime, style=circles, linewidth=4)
down = plot(down60on ? adopt('60', low_range): na, color = #DC143C, style=circles, linewidth=4) 

trans60 = up60on ?  75 : 100
fill(up, down, color = white, transp=trans60)

up30 = plot(up30on ? adopt('30', high_rangeL): na, color = #7FFF00, style=circles, linewidth=2) 
down30 = plot(down30on ? adopt('30', low_rangeL): na, color = red, style=circles, linewidth=2) 

//trans30 = up30on ?  70 : 100
//fill(up30, down30, color = white, transp=trans30)
```
