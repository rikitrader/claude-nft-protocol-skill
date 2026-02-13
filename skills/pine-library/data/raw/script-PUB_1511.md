---
id: PUB;1511
title: Gold Price Trend Overlay 
author: tux
type: indicator
tags: []
boosts: 195
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1511
---

# Description
Gold Price Trend Overlay 

# Source Code
```pine
study(title="TUX GOLD", shorttitle="TUX GOLD", overlay=true)
len = input(9, minval=1, title="Length")
src = input(close, title="Source")
out = sma(src, len)

gold = security("INDEX:XAU", "D", sma(close,len))  
goldc = iff(security("INDEX:XAU", "D", sma(close,len)) > security("INDEX:XAU", "D", close), red, orange)

plot(gold,linewidth=2, title="GOLD 1 DAY", color=goldc)


```
