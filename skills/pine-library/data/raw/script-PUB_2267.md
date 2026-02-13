---
id: PUB;2267
title: HL BREAKOUT
author: morpheus747
type: indicator
tags: []
boosts: 650
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2267
---

# Description
HL BREAKOUT

# Source Code
```pine
//@version=2
//Author Erik Czumadewski
//Very modified version from work done by Golgistain
study(title="HL BREAKOUT", shorttitle="HL/BO", overlay=true)
len = input(10, minval=1, title="High Length")
len2 = input(10, minval=1,title="Low Length")
bopips = input(0.0003, minval=0, type=float, title="Breakout PIPs")

h = highest(len)
hpivot = fixnan(h)

l = lowest(len2)
lpivot = fixnan(l)

plot(hpivot, color=lime, linewidth=2)
plot(lpivot, color=red, linewidth=2)

plotshape((lpivot<lpivot[1]) and ((close+bopips) < lpivot[1] or (close+bopips) < lpivot[2])?1:na, style=shape.triangledown, location=location.abovebar, color=aqua, size=size.small)
plotshape((hpivot>hpivot[1]) and ((close-bopips) > hpivot[1] or (close-bopips) > hpivot[2])?1:na, style=shape.triangleup, location=location.belowbar, color=purple, size=size.small)
```
