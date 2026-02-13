---
id: PUB;2211
title: [RS]Bollinger Bands Stop V0
author: RicardoSantos
type: indicator
tags: []
boosts: 816
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2211
---

# Description
[RS]Bollinger Bands Stop V0

# Source Code
```pine
study(title='[RS]Bollinger Bands Stop V0', shorttitle='BBS', overlay=true)
bb_src = input(title='Bollinger Band Source:', type=source, defval=close)
stop_src = input(title='Stop Source:', type=source, defval=close)
length = input(title='Length', type=integer, defval=20, minval=1)
mult = input(title='Band Deviation Multiplier:', type=float, defval=2.0, minval=0.001, maxval=50)
risk_multiplier = input(title='Risk Multiplier:', type=float, defval=0.5, minval=0.001, maxval=50)
SHOW_BB = input(title='Show Bollinger Bands?', type=bool, defval=false)
SHOW_ENTRY_ZONE = input(title='Show Entry Zone?', type=bool, defval=false)
SHOW_POINTS = input(title='Show Points?', type=bool, defval=false)

basis = sma(bb_src, length)
dev = mult * stdev(bb_src, length)
upper = basis + dev
lower = basis - dev

plot(title='BB-M', series=not SHOW_BB ? na : basis, color=gray)
p1 = plot(title='BB-U', series=not SHOW_BB ? na : upper, color=silver)
p2 = plot(title='BB-L', series=not SHOW_BB ? na : lower, color=silver)
fill(p1, p2, color=black, transp=90, title='BBf', editable=true)

trend = na(trend[1]) ? 1 : stop_src > upper[1] ? +1 : stop_src < lower[1] ? -1 : trend[1]

smin = trend < 0 ? min(nz(smin[1], upper[1]), upper) : na
smax = trend > 0 ? max(nz(smax[1], lower[1]), lower) : na

adjusted_min = trend < 0 ? min(nz(adjusted_min[1], smin[1]), smin - (risk_multiplier * dev)) : na
adjusted_max = trend > 0 ? max(nz(adjusted_max[1], smax[1]), smax + (risk_multiplier * dev)) : na

s0 = plot(title='S-', series=smin, style=linebr, color=black, transp=0)
s1 = plot(title='S+', series=smax, style=linebr, color=black, transp=0)
s2 = plot(title='E-', series=not SHOW_ENTRY_ZONE ? na : adjusted_min, style=linebr, color=black, transp=0)
s3 = plot(title='E+', series=not SHOW_ENTRY_ZONE ? na : adjusted_max, style=linebr, color=black, transp=0)
fill(s0, s2, color=red, transp=80, title='Z-', editable=true)
fill(s1, s3, color=lime, transp=80, title='Z+', editable=true)

overbought_end = crossunder(stop_src, upper)
oversold_end = crossover(stop_src, lower)

buy_entry_zone = stop_src < adjusted_max and stop_src > smax
sel_entry_zone = stop_src > adjusted_min and stop_src < smin

plot(title='Bz', series=not SHOW_POINTS ? na : buy_entry_zone ? low : na, style=circles, color=green, transp=0, linewidth=4)
plot(title='Sz', series=not SHOW_POINTS ? na : sel_entry_zone ? high : na, style=circles, color=maroon, transp=0, linewidth=4)
plot(title='Be', series=not SHOW_POINTS ? na : overbought_end ? high : na, style=circles, color=black, transp=0, linewidth=4)
plot(title='Se', series=not SHOW_POINTS ? na : oversold_end ? low : na, style=circles, color=black, transp=0, linewidth=4)

```
