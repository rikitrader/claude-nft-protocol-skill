---
id: PUB;1288
title: GS_Opening-Range-V1
author: cdiman
type: indicator
tags: []
boosts: 841
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1288
---

# Description
GS_Opening-Range-V1

# Source Code
```pine
study(title="GS_Opening-Range-V1", shorttitle="GS_OpenRnge-V1", overlay=true)

up30on = input(false, title="30 Minute Opening Range High")
down30on = input(false, title="30 Minute Opening Range Low")
up5on = input(true, title="5 Minute Opening Range High")
down5on = input(true, title="5 Minute Opening Range Low")
is_newbar(res) => change(time(res)) != 0 
adopt(r, s) => security(tickerid, r, s) 

high_range = valuewhen(is_newbar('D'),high,0)
low_range = valuewhen(is_newbar('D'),low,0)

high_rangeL = valuewhen(is_newbar('D'),high,0) 
low_rangeL = valuewhen(is_newbar('D'),low,0) 

up = plot(up5on ? adopt('5', high_range):na, color = lime, style=circles, linewidth=4)
down = plot(down5on ? adopt('5', low_range): na, color = #DC143C, style=circles, linewidth=4) 

trans30 = up30on ?  75 : 100
fill(up, down, color = white, transp=trans30)

up30 = plot(up30on ? adopt('30', high_rangeL): na, color = #7FFF00, style=circles, linewidth=2) 
down30 = plot(down30on ? adopt('30', low_rangeL): na, color = red, style=circles, linewidth=2) 

```
