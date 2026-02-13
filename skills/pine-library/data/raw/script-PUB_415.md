---
id: PUB;415
title: Indicators: Three included :: IFT on CCI, Z-Score and R-Squared
author: LazyBear
type: indicator
tags: []
boosts: 797
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_415
---

# Description
Indicators: Three included :: IFT on CCI, Z-Score and R-Squared

# Source Code
```pine
//
// @author LazyBear
// If you use this code in its orignal/modified form, do drop me a note. 
// 
study("Inverse Fisher Transform CCI [LazyBear]", shorttitle="IFTCCI_LB")
length = input(title="CCI Length", type=integer, defval=20)
src = close
cc=cci(src, length)

// Calculate IFT on CCI
lengthwma=input(9, title="Smoothing length")
calc_ifish(series, lengthwma) =>
    v1=0.1*(series-50)
    v2=wma(v1,lengthwma)
    ifish=(exp(2*v2)-1)/(exp(2*v2)+1)
    ifish

plot(calc_ifish(cc, lengthwma), color=teal, linewidth=1)
hline(0.5, color=red)
hline(-0.5, color=green)
hline(0)
```
