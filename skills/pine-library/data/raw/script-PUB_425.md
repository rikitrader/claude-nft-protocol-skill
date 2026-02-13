---
id: PUB;425
title: Indicators: Chartmill Value Indicator & Random Walk Index
author: LazyBear
type: indicator
tags: []
boosts: 509
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_425
---

# Description
Indicators: Chartmill Value Indicator & Random Walk Index

# Source Code
```pine
//
// @author LazyBear
//
// If you use this code in its original/modified form, do drop me a note. 
//
study("Chartmill Value Indicator [LazyBear]", shorttitle="CVI_LB")
length=input(3)
vc=sma(hl2, length)
useModifiedFormula=input(false, type=bool)
os1=input(-0.51, title="Oversold 1")
ob1=input(0.43, title="Overbought 1")

// os2=input(-1.5, title="Oversold 2")
// ob2=input(1.5, title="Overbought 2")

denom = (useModifiedFormula == true) ? (atr(length) * sqrt(length)) : atr(length)
cvi = (close-vc) / denom

plot(os1, color=green)
plot(ob1, color=red)

// plot(os2, color=green, style=3)
// plot(ob2, color=red, style=3)

plot(cvi, color=blue, linewidth=2)
```
