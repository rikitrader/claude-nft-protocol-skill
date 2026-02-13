---
id: PUB;511
title: Elastic Volume Weighted Moving Average & Envelope [LazyBear]
author: LazyBear
type: indicator
tags: []
boosts: 4567
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_511
---

# Description
Elastic Volume Weighted Moving Average & Envelope [LazyBear]

# Source Code
```pine
//
// @author LazyBear 
// List of all my indicators: https://www.tradingview.com/v/4IneGo8h/
//
study("Elastic Volume Weighted Moving Average [LazyBear]", shorttitle="EVWMA_LB", overlay=true)
length=input(20)
useCV=input(false, type=bool, title="Use Cumulative Volume")
renderBands=input(false, type=bool, title="Draw Envelope")
nbfs = useCV ? cum(volume) : sum(volume, length)
medianSrc=close
calc_evwma(price, length, nb_floating_shares) =>
    data = (nz(data[1]) * (nb_floating_shares - volume)/nb_floating_shares) + (volume*price/nb_floating_shares)
    data

m=calc_evwma(medianSrc, length, nbfs)
plot(m, color=maroon, linewidth=2, title="evwma")
plot(renderBands ? calc_evwma(high, length, nbfs): na, color=red  , linewidth=2, title="evwma+")
plot(renderBands ? calc_evwma(low, length, nbfs) : na, color=green, linewidth=2, title="evwma-")
```
