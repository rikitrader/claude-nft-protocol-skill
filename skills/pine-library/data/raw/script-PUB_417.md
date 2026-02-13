---
id: PUB;417
title: Indicators: Constance Brown Composite Index & RSI+Avgs
author: LazyBear
type: indicator
tags: []
boosts: 1987
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_417
---

# Description
Indicators: Constance Brown Composite Index & RSI+Avgs

# Source Code
```pine
//
// @author LazyBear
// Code from book "Breakthroughs in Technical Analysis" pg 95. 
//
// If you use this code in its orignal/modified form, do drop me a note. 
// 
study(title="Constance Brown Composite Index [LazyBear]", shorttitle="CBIDX_LB")
src = close
rsi_length=input(14, title="RSI Length")
rsi_mom_length=input(9, title="RSI Momentum Length")
rsi_ma_length=input(3, title="RSI MA Length")
ma_length=input(3, title="SMA Length")
fastLength=input(13)
slowLength=input(33)

r=rsi(src, rsi_length)
rsidelta = mom(r, rsi_mom_length)
rsisma = sma(rsi(src, rsi_ma_length), ma_length)
s=rsidelta+rsisma

plot(s, color=red, linewidth=2)
plot(sma(s, fastLength), color=green)
plot(sma(s, slowLength), color=orange)

```
