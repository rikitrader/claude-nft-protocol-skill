---
id: PUB;1755
title: [RS]Open Range Breakout V0
author: RicardoSantos
type: indicator
tags: []
boosts: 661
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1755
---

# Description
[RS]Open Range Breakout V0

# Source Code
```pine
//@version=2
study(title='[RS]Open Range Breakout V0', shorttitle='ORB', overlay=true)
//  Request for DCC
tf = input(title='Timeframe for open range:', type=string, defval='60', confirm=false)
f_is_new_day() => change(time('D'))!=0

ND_open = f_is_new_day() ? security(tickerid, tf, open) : ND_open[1]
ND_high = f_is_new_day() ? security(tickerid, tf, high) : ND_high[1]
ND_low = f_is_new_day() ? security(tickerid, tf, low) : ND_low[1]

ND_stretch = na(ND_stretch[1]) ? 0 : f_is_new_day() ? (ND_stretch[1]*9 + security(tickerid, tf, (high-open)>=(open-low)?high-open:open-low)) / 10 : ND_stretch[1]

filter_high = f_is_new_day() ? na : ND_high
filter_low = f_is_new_day() ? na : ND_low

filter_high_stretch = f_is_new_day() ? na : ND_high+ND_stretch
filter_low_stretch = f_is_new_day() ? na : ND_low-ND_stretch

fh = plot(title='TR', series=filter_high, style=linebr, color=black)
fl = plot(title='BR', series=filter_low, style=linebr, color=black)
fhs = plot(title='TS', series=filter_high_stretch, style=linebr, color=green)
fls = plot(title='BS', series=filter_low_stretch, style=linebr, color=maroon)
fill(title='Positive Stretch', plot1=fh, plot2=fhs, color=green, transp=50)
fill(title='Negative Stretch', plot1=fl, plot2=fls, color=maroon, transp=50)
```
