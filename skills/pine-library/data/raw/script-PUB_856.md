---
id: PUB;856
title: CM_3-Stochastics_No%D_UserRequest
author: ChrisMoody
type: indicator
tags: []
boosts: 2161
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_856
---

# Description
CM_3-Stochastics_No%D_UserRequest

# Source Code
```pine
//Created By ChrisMoody on 1-19-2014 by User Request from eaglenestfund
//Plots 3 Stoch Lines.....No %D Lines

study(title="CM_3-Stochastics_No%D_UserRequest", shorttitle="CM_3-Stochs_No%D", precision=0)
length1 = input(8, minval=1)
smoothK1 = input(3, minval=1) 
smoothD1 = input(3, minval=1)
length2 = input(16, minval=1)
smoothK2 = input(3, minval=1) 
smoothD2 = input(3, minval=1)
length3 = input(34, minval=1)
smoothK3 = input(3, minval=1) 
smoothD3 = input(3, minval=1)
upt = input(80, minval=50, maxval=100, title="Upper Line")
lot = input(20, minval=1, maxval=50, title="Lower Line")

k1 = sma(stoch(close, high, low, length1), smoothK1)
d1 = sma(k1, smoothD1)

k2 = sma(stoch(close, high, low, length2), smoothK2)
d2 = sma(k2, smoothD2)

k3 = sma(stoch(close, high, low, length3), smoothK3)
d3 = sma(k3, smoothD3)

upperLine = upt
lowerLine = lot

plot(k1, title="Fast Stochastic", style=line, linewidth=2, color=red)
//plot(d1, color=orange)
plot(k2, title="Medium Stochastic", style=line, linewidth=2, color=aqua)
//plot(d2, color=orange)
plot(k3, title="Slow Stochastic", style=line, linewidth=2, color=gray)
//plot(d3, color=orange)
p1 = plot(upperLine, title="Upper Line", style=line, linewidth=3, color=red)
p2 = plot(lowerLine, title="Lower Line", style=line, linewidth=3, color=lime)
fill(p1, p2, color=gray, transp=90)
```
