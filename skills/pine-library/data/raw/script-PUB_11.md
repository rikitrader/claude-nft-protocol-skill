---
id: PUB;11
title: Indicator: Kairi Relative Index (KRI)
author: LazyBear
type: indicator
tags: []
boosts: 811
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_11
---

# Description
Indicator: Kairi Relative Index (KRI)

# Source Code
```pine
//
// @author LazyBear
//
// http://www.investopedia.com/articles/forex/09/kairi-relative-strength-index.asp
// The Kairi Relative Index is considered an oscillator as well as a leading indicator.
//

study("Kairi Relative Index [LazyBear]", shorttitle="KAIRI_LB")
length=input(14)
ki(src)=>
    ((src - sma(src, length))/sma(src, length)) * 100

hline(0)
plot(ki(close), color=red, linewidth=2)


```
