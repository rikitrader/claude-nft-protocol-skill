---
id: PUB;904
title: RSI-Stochastic Hybrid v2
author: blindfreddy
type: indicator
tags: []
boosts: 748
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_904
---

# Description
RSI-Stochastic Hybrid v2

# Source Code
```pine
//Scripted by Blind Freddy
//See my blog at http://blindfreddy.postagon.com for learning and picks
//Hybrid RSI-Stochastic Indicator v2, with optional smoothing and EMA line
study(title="RSI-Stoch Hybrid v2", shorttitle="RSI-Stoch", overlay=false)
len = input(14, minval=1, title="RSI Length")
lenRSIsmth = input(3,minval=1, title = "RSI Smoothing")
lenstoch = input(26, minval=1, title="Stochastic Length")
lenStochsmth = input(3,minval=1, title = "Stoch Smoothing")
thepercent = input(50, minval=0, maxval = 100, title="Percent RSI")
len2 = input(5, minval=1, title="EMA (Signal) Length")
thersi= ema(rsi(close,len),lenRSIsmth)
thestoch=ema(stoch(close,high,low,lenstoch),lenStochsmth)
thehybrid=thersi*thepercent/100 + thestoch*(100-thepercent)/100
theEMA = ema(thehybrid,len2)
plot(thehybrid, title="RSI-Stoch Hybrid", style=line, linewidth=2, color=teal)
plot(theEMA, title="EMA", style=line, linewidth=2, color=gray)
band2 = hline(80, title="Upper Line", linestyle=dashed, linewidth=1)
band1 = hline(50, title="Upper Line", linestyle=dashed, linewidth=1)
band0 = hline(20, title="Lower Line", linestyle=dashed, linewidth=1)
fill(band2, band0, color=blue, transp=90)
```
