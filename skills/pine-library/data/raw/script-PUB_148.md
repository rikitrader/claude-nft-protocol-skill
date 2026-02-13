---
id: PUB;148
title: Indicator: Price Headley Accelaration Bands [LazyBear]
author: LazyBear
type: indicator
tags: []
boosts: 1026
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_148
---

# Description
Indicator: Price Headley Accelaration Bands [LazyBear]

# Source Code
```pine
//
// @author LazyBear
//
// If you use this code in its orignal/modified form, do drop me a note. 
// 
study(title = "Price Headley Accelaration Bands [LazyBear]", shorttitle="PHAB_LB", overlay=true)
length=input(20)
ub=(high*(1+2*((((high-low)/((high+low)/2))*1000)*0.001)))
su=sma(ub, length )
lb=(low*(1-2*((((high-low)/((high+low)/2))*1000)*0.001)))
sl=sma(lb, length )
u=plot(su, color=blue, linewidth=2)
l=plot(sl, color=red, linewidth=2)
fill(u,l,gray, transp=90)
plot(avg(su,sl), style=3, color=gray)

```
