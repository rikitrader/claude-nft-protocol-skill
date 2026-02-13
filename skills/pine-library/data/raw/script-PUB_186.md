---
id: PUB;186
title: MAC-Z Indicator [LazyBear]
author: LazyBear
type: indicator
tags: []
boosts: 2207
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_186
---

# Description
MAC-Z Indicator [LazyBear]

# Source Code
```pine
//
// @author LazyBear 
// List of all my indicators: https://www.tradingview.com/v/4IneGo8h/
//
study("MAC-Z Indicator [LazyBear]", shorttitle="MACZ_LB")
fastLength = input(12, minval=1, title="MACD Fast MA Length"), slowLength=input(25,minval=1, title="MACD Slow MA Length")
signalLength=input(9, title="MACD Signal Length")
lengthz = input(25, title="ZScore Length")
lengthStdev=input(25, title="Stdev Length")
A=input(1.0, minval=-2.0, maxval=2.0, title="MACZ constant A")
B=input(1.0, minval=-2.0, maxval=2.0, title="MACZ constant B")
useLag=input(false, type=bool, title="Apply Laguerre Smoothing")
gamma = input(0.02, title="Laguerre Gamma")

source = close
calc_wima(src, length) => 
    MA_s=(src + nz(MA_s[1] * (length-1)))/length
    MA_s

calc_laguerre(s,g) =>
    l0 = (1 - g)*s+g*nz(l0[1])
    l1 = -g*l0+nz(l0[1])+g*nz(l1[1])
    l2 = -g*l1+nz(l1[1])+g*nz(l2[1])
    l3 = -g*l2+nz(l2[1])+g*nz(l3[1])
    (l0 + 2*l1 + 2*l2 + l3)/6


zscore = ( source - calc_wima( source, lengthz ) ) / stdev( source, lengthz )
fastMA = sma(source, fastLength)
slowMA = sma(source, slowLength)
macd = fastMA - slowMA
macz_t=zscore*A+ macd/stdev(source, lengthStdev)*B
macz=useLag ? calc_laguerre(macz_t,gamma) : macz_t
signal=sma(macz, signalLength)
hist=macz-signal

plot(hist, color=red, style=histogram, title="Histogram")
plot(macz, color=green, title="MAC-Z")
plot(signal, color=orange, title="Signal")



```
