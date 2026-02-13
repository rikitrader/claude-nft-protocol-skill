---
id: PUB;441
title: MAC-Z VWAP Indicator [LazyBear]
author: LazyBear
type: indicator
tags: []
boosts: 2956
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_441
---

# Description
MAC-Z VWAP Indicator [LazyBear]

# Source Code
```pine
//
// @author LazyBear 
// List of all my indicators: https://www.tradingview.com/v/4IneGo8h/
//
study("MAC-Z VWAP Indicator [LazyBear]", shorttitle="MACZVWAP_LB")
fastLength = input(12, minval=1, title="MACD Fast MA Length"), slowLength=input(25,minval=1, title="MACD Slow MA Length")
signalLength=input(9, title="MACD Signal Length")
lengthz = input(20, title="Z-VWAP Length")
lengthStdev=input(25, title="Stdev Length")
A=input(1.0, minval=-2.0, maxval=2.0, title="MACZ constant A")
B=input(1.0, minval=-2.0, maxval=2.0, title="MACZ constant B")
useLag=input(false, type=bool, title="Apply Laguerre Smoothing")
gamma = input(0.02, title="Laguerre Gamma")
source = close

calc_laguerre(s,g) =>
    l0 = (1 - g)*s+g*nz(l0[1])
    l1 = -g*l0+nz(l0[1])+g*nz(l1[1])
    l2 = -g*l1+nz(l1[1])+g*nz(l2[1])
    l3 = -g*l2+nz(l2[1])+g*nz(l3[1])
    (l0 + 2*l1 + 2*l2 + l3)/6


calc_zvwap(pds) =>
	mean = sum(volume*close,pds)/sum(volume,pds)
	vwapsd = sqrt(sma(pow(close-mean, 2), pds) )
	(close-mean)/vwapsd

zscore = calc_zvwap(lengthz)
fastMA = sma(source, fastLength)
slowMA = sma(source, slowLength)
macd = fastMA - slowMA
macz_t=zscore*A+ macd/stdev(source, lengthStdev)*B
macz=useLag ? calc_laguerre(macz_t,gamma) : macz_t
signal=sma(macz, signalLength)
hist=macz-signal

plot(hist, color=red, style=area, title="Histogram", transp=85)
plot(macz, color=green, title="MAC-Z", linewidth=2)
plot(signal, color=orange, title="Signal", linewidth=2)

```
