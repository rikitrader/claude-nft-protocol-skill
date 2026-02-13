---
id: PUB;1877
title: JKSW Strength momentum index v2
author: jkswoods
type: indicator
tags: []
boosts: 291
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1877
---

# Description
JKSW Strength momentum index v2

# Source Code
```pine
study(title="JKSW Strength momentum index v2", shorttitle="JKSW SMI v2")

// Plot the RSI 
src = input(ohlc4, "Source")

shortlen = input(10, "Short term bars", integer)
midlen = input(35, "Mid term bars", integer)
longlen = input(110, "Long term bars", integer)

shortup = rma(max(change(src), 0), shortlen)
shortdown = rma(-min(change(src), 0), shortlen)

midup = rma(max(change(src), 0), midlen)
middown = rma(-min(change(src), 0), midlen)

longup = rma(max(change(src), 0), longlen)
longdown = rma(-min(change(src), 0), longlen)

short = shortdown == 0 ? 100 : shortup == 0 ? 0 : 100 - (100 / (1 + shortup / shortdown))
mid = middown == 0 ? 100 : midup == 0 ? 0 : 100 - (100 / (1 + midup / middown))
long = longdown == 0 ? 100 : longup == 0 ? 0 : 100 - (100 / (1 + longup / longdown))

// Overbought line
hline(80, "Overbought", black, dotted, 2)
// Oversold line
hline(20, "Oversold", black, dotted, 2)
// Mid line
hline(50, "Mid line", black, dotted)

// Plot on the chart where the points cross
color = short > mid ? short > long ? green : yellow : short < long ? red : yellow 
plot(short, color=color, title="SMI")
barcolor(color)

```
