---
id: PUB;526
title: CCT Bollinger Band Oscillator
author: LazyBear
type: indicator
tags: []
boosts: 5559
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_526
---

# Description
CCT Bollinger Band Oscillator

# Source Code
```pine
//
// @author LazyBear 
// List of all my indicators: 
// https://docs.google.com/document/d/15AGCufJZ8CIUvwFJ9W-IKns88gkWOKBCvByMEvm5MLo/edit?usp=sharing
//
study("CCT Bollinger Band Oscillator [LazyBear]", shorttitle="CCTBBO_LB")
length=input(21)
lengthMA=input(13)
src=close
cctbbo=100 * ( src + 2*stdev( src, length) - sma( src, length ) ) / ( 4 * stdev( src, length ) )

ul=hline(100, color=gray)
ll=hline(0, color=gray)
hline(50, color=gray)
fill(ul,ll, color=blue)

plot(cctbbo, color=blue, linewidth=2)
plot(ema(cctbbo, lengthMA), color=red)

```
