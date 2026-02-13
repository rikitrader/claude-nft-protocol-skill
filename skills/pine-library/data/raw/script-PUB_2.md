---
id: PUB;2
title: Indicator: Elder Impulse System
author: LazyBear
type: indicator
tags: []
boosts: 5999
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2
---

# Description
Indicator: Elder Impulse System

# Source Code
```pine
//
// @author LazyBear
//
// If you use this code in its original/modified form, do drop me a note. 
//
study("Elder Impulse System [LazyBear]", shorttitle="EIS_LB")
useCustomResolution=input(false, type=bool)
customResolution=input("D", type=resolution)
source = security(tickerid, useCustomResolution ? customResolution : period, close)
showColorBars=input(false, type=bool)
lengthEMA = input(13)
fastLength = input(12, minval=1), slowLength=input(26,minval=1)
signalLength=input(9,minval=1)

calc_hist(source, fastLength, slowLength) =>
    fastMA = ema(source, fastLength)
    slowMA = ema(source, slowLength)
    macd = fastMA - slowMA
    signal = sma(macd, signalLength)
    macd - signal

get_color(emaSeries, macdHist) =>
    g_f = (emaSeries > emaSeries[1]) and (macdHist > macdHist[1])
    r_f = (emaSeries < emaSeries[1]) and (macdHist < macdHist[1])
    g_f ? green : r_f ? red : blue
    
b_color = get_color(ema(source, lengthEMA), calc_hist(source, fastLength, slowLength))    
bgcolor(b_color, transp=0)
barcolor(showColorBars ? b_color : na)

```
