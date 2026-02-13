---
id: PUB;429
title: Indicators: Rainbow Charts Oscillator, Binary Wave and MAs
author: LazyBear
type: indicator
tags: []
boosts: 1312
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_429
---

# Description
Indicators: Rainbow Charts Oscillator, Binary Wave and MAs

# Source Code
```pine
//
// @author LazyBear
//
// If you use this code in its original/modified form, do drop me a note. 
//
study("Rainbow Charts Oscillator [LazyBear]", shorttitle="RCO_LB")
sma2=sma(close,2)
dsma2=sma(sma2,2)
tsma2=sma(dsma2,2)
qsma2=sma(tsma2,2)
psma2=sma(qsma2,2)
ssma2=sma(psma2,2)
s2sma2=sma(ssma2,2)
osma2=sma(s2sma2,2)
o2sma2=sma(osma2,2)
desma2=sma(o2sma2,2)

rmax=max(sma2,max(dsma2,max(tsma2,max(qsma2,max(psma2,max(ssma2,max(s2sma2,max(osma2,max(o2sma2,desma2)))))))))
rmin=min(sma2,min(dsma2,min(tsma2,min(qsma2,min(psma2,min(ssma2,min(s2sma2,min(osma2,min(o2sma2,desma2)))))))))
rosc=100*(close-((sma2+dsma2+tsma2+qsma2+psma2+ssma2+s2sma2+osma2+o2sma2+desma2)/10))/(highest(close,10)-lowest(close,10))
rbl=-100*(rmax-rmin)/(highest(close,10)-lowest(close,10))
rbu=-rbl //100*(rmax-rmin)/(highest(close,10)-lowest(close,10))
ml=plot(0)
ll=plot(rbl, color=gray)
ul=plot(rbu, color=gray)
plot(rosc, color=rosc>=0?green:red, linewidth=3, style=histogram)

fill(ll, ml, red)
fill(ml, ul, green)
```
