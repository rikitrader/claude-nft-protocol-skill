---
id: PUB;1794
title: [RS]Linear Regression Bands V2
author: RicardoSantos
type: indicator
tags: []
boosts: 277
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1794
---

# Description
[RS]Linear Regression Bands V2

# Source Code
```pine
study(title="[RS]Linear Regression Bands V2", shorttitle="LRB", overlay=true)
decay_ratio = input(title='Decay ratio:', type=float, defval=0.125)
smooth = input(title='Smoothing:', type=integer, defval=4)

prehh1 = nz(hh1[1], high)
prell1 = nz(ll1[1], low)

hh1 = close >= prehh1 ? high : prehh1 - sma(abs(change(high, 1)*decay_ratio), smooth)
ll1 = close <= prell1 ? low : prell1 + sma(abs(change(low, 1)*decay_ratio), smooth)
midline = avg(hh1, ll1)
plot(title='M', series=midline, style=cross, color=black, linewidth=1)
ph1 = plot(title='T', series=hh1, style=line, color=black, linewidth=1)
pl1 = plot(title='B', series=ll1, style=line, color=black, linewidth=1)

margin = input(title='Signal margin:', type=float, defval=30.0) * syminfo.mintick
signalcolor = high-margin > hh1 ? maroon : low+margin < ll1 ? green : gray
signal = high-margin > hh1 ? high+margin : low+margin < ll1 ? low-margin : na
plot(title='S', series=signal, style=circles, color=signalcolor, linewidth=4)
```
