---
id: PUB;824
title: Anchored Momentum [LazyBear]
author: LazyBear
type: indicator
tags: []
boosts: 1683
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_824
---

# Description
Anchored Momentum [LazyBear]

# Source Code
```pine
//
// @author LazyBear 
// List of all my indicators: 
// https://docs.google.com/document/d/15AGCufJZ8CIUvwFJ9W-IKns88gkWOKBCvByMEvm5MLo/edit?usp=sharing
// 
study("Anchored Momentum [LazyBear]", shorttitle="AMOM_LB")
src=close
l=input(10, title="Momentum Period")
sl=input(8, title="Signal Period")
sm=input(false, title="Smooth Momentum")
smp=input(7, title="Smoothing Period")
sh=input(false, title="Show Histogram")
eb=input(false, title="Enable Barcolors")
p=2*l+1
amom=100*(((sm?ema(src,smp):src)/(sma(src,p)) - 1))
amoms=sma(amom, sl)
hline(0, title="ZeroLine")
hl=sh ? amoms<0 and amom<0 ? max(amoms, amom) : amoms>0 and amom>0 ? min(amoms, amom) : 0 : na
hlc=(amom>amoms)?(amom<0?orange:green):(amom<0?red:orange)
plot(sh?hl:na, style=histogram, color=hlc, linewidth=2)
plot(amom, color=red, linewidth=2, title="Momentum")
plot(amoms, color=green, linewidth=2, title="Signal")
barcolor(eb?hlc:na)
```
