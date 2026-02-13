---
id: PUB;459
title: Bollinger Bands %B Bollinger Bands - Version 2
author: UDAY_C_Santhakumar
type: indicator
tags: []
boosts: 3551
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_459
---

# Description
Bollinger Bands %B Bollinger Bands - Version 2

# Source Code
```pine
//Updated by ChrisMoody on 8/14/2014 --  Original Code From ucsgears
study(title = "Bollinger Bands %B Bollinger Bands", shorttitle = "BB %B BB")
source = close
length = input(20, minval=1), mult = input(2.0, minval=0.001, maxval=50)
basis = sma(source, length)
dev = mult * stdev(source, length)
upper = basis + dev
lower = basis - dev
bbr = (source - lower)/(upper - lower)
//plot(bbr, color=teal)
 
basisa = sma(bbr, length)
deva = mult * stdev(bbr, length)
uppera = basisa + deva
lowera = basisa - deva
 
//Added This
aboveUp = bbr > uppera ? 1 : 0
belowDn = bbr < lowera ? 1 : 0
plotchar(aboveUp, title="i", char='S', location=location.top, color=red, transp=0, offset=0)
plotchar(belowDn, title="i", char='B', location=location.bottom, color=green, transp=0, offset=0)
 
//Added in BackGround Hilighting
noTrade = aboveUp == 0 and belowDn == 0
bgcolor(noTrade ? gray : na, transp=50)
bgcolor(aboveUp ? red : na, transp=60)
bgcolor(belowDn ? green : na, transp=60)
 
//Added This
col = bbr < lowera ? lime : bbr > uppera ? red : teal
 
//Changed your plot fills from Midline to top of band...and midline to lower band.
p1 = plot(basisa, color=silver, linewidth=0)
p2 = plot(uppera, color=red, linewidth=2)
p3 = plot(lowera, color=green, linewidth=2)
fill(p1, p2, color=red, transp = 70)
fill(p1, p3, color=green, transp = 70)
plot(bbr, color= col, style=linebr, linewidth=3)
```
