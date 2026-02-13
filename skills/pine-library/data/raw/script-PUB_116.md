---
id: PUB;116
title: FREE INDICATOR: CHOPPINESS INDEX  "TREND DETECTION FROM CHAOS"
author: TheLark
type: indicator
tags: []
boosts: 1356
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_116
---

# Description
FREE INDICATOR: CHOPPINESS INDEX  "TREND DETECTION FROM CHAOS"

# Source Code
```pine
study("TheLark: Choppiness Index", overlay=false)

length = input(14, title="Length")
doavg = input(true,title="Do Average?")
avg = input(4, title="Average Length")
l1 = input(61.8, title="Extreme Chop")
l2 = input(50.0, title="Midline")
l3 = input(38.2, title="Trending")

str = sum(tr,length)
ltl = lowest(low <= close[1] ? low : close[1],length)
hth = highest(high >= close[1] ? high : close[1],length)
height = hth - ltl
chop = 100 * (log10(str / height) / log10(length))

plot(chop, color=#42B0FF, linewidth=2)
plot(doavg ? sma(chop,avg) : na, color=white)
hli1 = hline(l1)
hli2 = hline(l2)
hli3 = hline(l3)

fill(hli1,hli2,black,80)
fill(hli2,hli3,#C8D974,80)


```
