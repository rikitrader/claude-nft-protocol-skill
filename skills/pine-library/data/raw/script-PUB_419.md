---
id: PUB;419
title: Indicators: Volume Zone Indicator & Price Zone Indicator
author: LazyBear
type: indicator
tags: []
boosts: 2524
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_419
---

# Description
Indicators: Volume Zone Indicator & Price Zone Indicator

# Source Code
```pine
//
// @author LazyBear
//
// If you use this code in its original/modified form, do drop me a note. 
//
study("Volume Zone Oscillator [LazyBear]", shorttitle="VZO_LB")
length=input(20, title="MA Length")

dvol=sign(close-close[1]) * volume
dvma=ema(dvol, length)
vma=ema(volume, length)
vzo=iff(vma != 0, 100 * dvma / vma,0)

hline(60, color=red)
hline(40, color=gray)
hline(20, color=gray)
hline(0, color=gray)
hline(-20, color=gray)
hline(-40, color=gray)
hline(-60, color=green)

plot(vzo, color=maroon, linewidth=2)
```
