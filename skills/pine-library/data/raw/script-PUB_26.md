---
id: PUB;26
title: Indicator: Tirone Levels
author: LazyBear
type: indicator
tags: []
boosts: 487
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_26
---

# Description
Indicator: Tirone Levels

# Source Code
```pine
//
// @author LazyBear
// Tirone Levels are dynamic S/R levels
// 
study(title = "Tirone Levels [LazyBear]", shorttitle="TironeLvl_LB", overlay=true)
length=input(20)
method_mp=input(false, title="Midpoint Method?", type=bool)
method_mm=input(true, title="Mean Method?", type=bool)

ll=lowest(low, length)
hh=highest(high, length)

// Midpoint method
tlh = hh - ((hh-ll)/3)
clh = ll + ((hh-ll)/2)
blh = ll + ((hh-ll)/3)
tl = plot(method_mp ? tlh : na, color = red)
cl = plot(method_mp ? clh : na)
bl = plot(method_mp ? blh : na, color = green)

// Mean method
am  = (hh+ll+close)/3
eh = am + (hh-ll)
el = am - (hh-ll)
rh = 2*am - ll
rl = 2*am - hh

ehl = plot(method_mm ? eh : na, color = red)
rhl = plot(method_mm ? rh : na, color = red)
aml = plot(method_mm ? am : na)
rll = plot(method_mm ? rl : na, color = green)
ell = plot(method_mm ? el : na, color = green)
```
