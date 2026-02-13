---
id: PUB;285
title: Indicator: Intrady Momentum Index
author: LazyBear
type: indicator
tags: []
boosts: 2862
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_285
---

# Description
Indicator: Intrady Momentum Index

# Source Code
```pine
//
// @author LazyBear 
// List of all my indicators: https://www.tradingview.com/v/4IneGo8h/
//
study("Intrady Momentum Index [LazyBear]", shorttitle="IMI_LB")
length=input(14, "IMI Length")
lengthMA=input(6, "IMI MA Length")
obLevel=input(70, "IMI static OB level")
osLevel=input(20, "IMI static OS level")
mult=input(2.0, title="Volatility Bands Stdev Mult")
lengthBB=input(20, title="Volatility Bands Length")
applySmoothing=input(false, "Smooth IMI")
lowBand=input(10, "Smoothing LowerBand")
PI=3.14159265359
EhlersSuperSmootherFilter(price, lower) =>
	a1 = exp(-PI * sqrt(2) / lower)
	coeff2 = 2 * a1 * cos(sqrt(2) * PI / lower)
	coeff3 = - pow(a1,2)
	coeff1 = 1 - coeff2 - coeff3
	filt = coeff1 * (price + nz(price[1])) / 2 + coeff2 * nz(filt[1]) + coeff3 * nz(filt[2]) 
	filt

gains=iff(close>open,nz(gains[1])+(close-open),0)
losses=iff(close<open,nz(losses[1])+(open-close),0)
upt=sum(gains,length)
dnt=sum(losses,length)
imi=applySmoothing ? EhlersSuperSmootherFilter(100*(upt/(upt+dnt)), lowBand) : 100*(upt/(upt+dnt))
basisx=ema(imi, lengthBB)
devx = (mult * stdev(imi, lengthBB))
ulx = (basisx + devx)
llx = (basisx - devx)

// Uncomment if you want more bands
//hline(90)
//hline(10)
hline(obLevel)
hline((obLevel+osLevel)/2, linestyle=dotted)
hline(osLevel)
plot(imi, color=red, linewidth=2)
plot(imi>=ulx? imi : na, color=green, style=cross, linewidth=3 )
plot(imi<=llx? imi : na, color=maroon, style=cross, linewidth=3 )
plot(ema(imi, lengthMA), color=blue)
```
