---
id: PUB;530
title: Vervoort Smoothed %b [LazyBear]
author: LazyBear
type: indicator
tags: []
boosts: 854
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_530
---

# Description
Vervoort Smoothed %b [LazyBear]

# Source Code
```pine
//
// @author LazyBear 
// List of all my indicators: 
// https://docs.google.com/document/d/15AGCufJZ8CIUvwFJ9W-IKns88gkWOKBCvByMEvm5MLo/edit?usp=sharing
//
study("Vervoort Modified BB%b [LazyBear]", shorttitle="VMBB%b_LB")
calc_tema(s, length) =>
    ema1 = ema(s, length)
    ema2 = ema(ema1, length)
    ema3 = ema(ema2, length)
    3 * (ema1 - ema2) + ema3

length=input(18, minval=2, maxval=100, title="%B Length")
temaLength=input(8, title="TEMA Length")
stdevHigh=input(1.6, title="Stdev High")
stdevLow=input(1.6, title="Stdev Low")
stdevLength=input(200, title="Stdev Length")
haOpen=(ohlc4[1]+nz(haOpen[1]))/2
haC=(ohlc4+haOpen+max(high, haOpen)+min(low, haOpen))/4

tma1 = calc_tema(haC,temaLength)
tma2 = calc_tema(tma1, temaLength)
diff = tma1-tma2
zlha = tma1+diff
percb = (calc_tema(zlha,temaLength)+2*stdev(calc_tema(zlha,temaLength),length) - wma(calc_tema(zlha,temaLength),length))/(4*stdev(calc_tema(zlha,temaLength),length))*100

ub=50+stdevHigh*stdev(percb,stdevLength)
lb=50-stdevLow*stdev(percb,stdevLength)
ul=plot(ub, color=red, title="Stdev+")
ll=plot(lb, color=green, title="Stdev-")
plot((ub+lb)/2, color=blue, style=3, title="Stdev Mid")
fill(ul, ll, red)
plot(percb, linewidth=2, color=maroon, title="SVE %b")


```
