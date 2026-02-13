---
id: PUB;2213
title: Kaufman Binary Wave [LazyBear] Non overlaid
author: lonestar108
type: indicator
tags: []
boosts: 495
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2213
---

# Description
Kaufman Binary Wave [LazyBear] Non overlaid

# Source Code
```pine
//
// @author LazyBear
// If you use this code in its original/modified form, do drop me a note.
// My other indicators: https://www.tradingview.com/u/LazyBear/#published-charts
//
study(title = "Kaufman Binary Wave [LazyBear]", shorttitle="AMAWave_LB", overlay=false)
src=close
length=input(20)
filterp = input(10, title="Filter %", type=integer)
cf=input(true, "Color Buy/Sell safe areas?", type=bool)
dw=input(true, "Draw Wave?", type=bool)
 
d=abs(src-src[1])
s=abs(src-src[length])
noise=sum(d, length)
efratio=s/noise
fastsc=0.6022
slowsc=0.0645
 
smooth=pow(efratio*fastsc+slowsc, 2)
ama=nz(ama[1], close)+smooth*(src-nz(ama[1], close))
filter=filterp/100 * stdev(ama-nz(ama), length)
amalow=ama < nz(ama[1]) ? ama : nz(amalow[1])
amahigh=ama > nz(ama[1]) ? ama : nz(amahigh[1])
bw=(ama-amalow) > filter ? 1 : (amahigh-ama > filter ? -1 : 0)
s_color=cf ? (bw > 0 ? green : (bw < 0) ? red : blue) : maroon
plot(dw ? bw : na, color=s_color)
bgcolor(cf ? s_color : na)
hline(0)
```
