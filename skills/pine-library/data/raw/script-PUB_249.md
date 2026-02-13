---
id: PUB;249
title: Ehlers Smoothed Stochastic & RSI with Roofing Filters
author: LazyBear
type: indicator
tags: []
boosts: 2309
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_249
---

# Description
Ehlers Smoothed Stochastic & RSI with Roofing Filters

# Source Code
```pine
//
// @author LazyBear 
// List of all my indicators: https://www.tradingview.com/v/4IneGo8h/
//
study("Ehlers Smoothed Stochastic [LazyBear]", shorttitle="ESSTOCH_LB")
PI=3.14159265359
applyDoubleSmoothing=input(false, type=bool)
length = input (14, title="Stoch Length")
lengthMA=input (3, title="Stoch MA Length")
over_bought = input (.8)
over_sold = input (.2)
src=close
roofingBandUpper=input(48)
roofingBandLower=input(10)

EhlersSuperSmootherFilter(price, lower) =>
	a1 = exp(-PI * sqrt(2) / lower)
	coeff2 = 2 * a1 * cos(sqrt(2) * PI / lower)
	coeff3 = - pow(a1,2)
	coeff1 = 1 - coeff2 - coeff3
	filt = coeff1 * (price + nz(price[1])) / 2 + coeff2 * nz(filt[1]) + coeff3 * nz(filt[2]) 
	filt

EhlersRoofingFilter(price, smoothed, upper, lower) =>  
	alpha1 = (cos(sqrt(2) * PI / upper) + sin (sqrt(2) * PI / upper) - 1) / cos(sqrt(2) * PI / upper)
	highpass = pow(1 - alpha1 / 2, 2) * (price - 2 * nz(price[1]) + nz(price[2])) + 
 	            2 * (1 - alpha1) * nz(highpass[1]) - pow(1 - alpha1, 2) * nz(highpass[2])
	smoothed ? EhlersSuperSmootherFilter(highpass, lower) : highpass
    
EhlersStochastic(price, length, applyEhlerSmoothing, roofingBandUpper, roofingBandLower) =>
	filt = EhlersRoofingFilter(price, applyEhlerSmoothing, roofingBandUpper, roofingBandLower)
	highestP = highest(filt, length)
	lowestP = lowest(filt, length)
	iff ((highestP - lowestP) != 0, (filt - lowestP) / (highestP - lowestP),  0)


stoch=EhlersSuperSmootherFilter(EhlersStochastic(src, length, applyDoubleSmoothing, roofingBandUpper, roofingBandLower), roofingBandLower)
hline (over_bought)
hline (over_sold)
hline((over_bought+over_sold)/2)
plot(sma(stoch, lengthMA), color=red, linewidth=1)
plot(stoch, color=blue, linewidth=1)

 
```
