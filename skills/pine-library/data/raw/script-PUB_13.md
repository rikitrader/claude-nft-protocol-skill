---
id: PUB;13
title: Indicator: Ulcer Index
author: LazyBear
type: indicator
tags: []
boosts: 596
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_13
---

# Description
Indicator: Ulcer Index

# Source Code
```pine
// @author LazyBear
// Ulcer Index 
// @credits http://www.tangotools.com/ui/ui.htm

study(title = "Ulcer Index [LazyBear]", shorttitle="UlcerIndex_LB")
length=input(10)
cutoff=input(5)
hcl=highest(close,length)
r=100.0*((close-hcl)/hcl)
ui=sqrt(sum(pow(r,2), length)/length)
sl=plot(ui, color=ui>cutoff ? red : aqua)
hline(cutoff, color=red)
bl=plot(cutoff)
fill(sl,bl,color=silver)


```
