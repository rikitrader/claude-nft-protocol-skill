---
id: PUB;411
title: 3 more indicators: Inverse Fisher on RSI/MFI and CyberCycle
author: LazyBear
type: indicator
tags: []
boosts: 2983
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_411
---

# Description
3 more indicators: Inverse Fisher on RSI/MFI and CyberCycle

# Source Code
```pine
//
// @author LazyBear
// If you use this code in its orignal/modified form, do drop me a note. 
// 
study("Inverse Fisher Transform RSI [LazyBear]", shorttitle="IFTRSI_LB")
s=close
length=input(14, "RSI length")
lengthwma=input(9, title="Smoothing length")

calc_ifish(series, lengthwma) =>
    v1=0.1*(series-50)
    v2=wma(v1,lengthwma)
    ifish=(exp(2*v2)-1)/(exp(2*v2)+1)
    ifish

plot(calc_ifish(rsi(s, length), lengthwma), color=orange, linewidth=2)
hline(0.5, color=red)
hline(-0.5, color=green)
```
