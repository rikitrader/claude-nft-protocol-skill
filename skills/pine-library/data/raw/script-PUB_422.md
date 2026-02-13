---
id: PUB;422
title: Indicators: Butterworth & Super Smoother filters
author: LazyBear
type: indicator
tags: []
boosts: 476
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_422
---

# Description
Indicators: Butterworth & Super Smoother filters

# Source Code
```pine
//
// @author LazyBear
// 
// If you use this code in its original/modified form, do drop me a note. 
//
study("Two Pole Super Smoother Filter [LazyBear]", shorttitle="2PSSF_LB", overlay=true)
p=hl2
length=input(13)

a1=exp(-1.414*3.14159/length)
b1=2*a1*cos(1.414*180/length)
coef2=b1
coef3=-a1*a1
coef1=1-coef2-coef3
f2 = coef1*p+coef2*nz(f2[1])+coef3*nz(f2[2])
plot(f2,"2-Pole Super Smoother", color=black, linewidth=2)
```
