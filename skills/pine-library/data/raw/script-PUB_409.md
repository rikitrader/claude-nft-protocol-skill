---
id: PUB;409
title: [REPOST] Indicators: 3 Different Adaptive Moving Averages
author: LazyBear
type: indicator
tags: []
boosts: 2030
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_409
---

# Description
[REPOST] Indicators: 3 Different Adaptive Moving Averages

# Source Code
```pine
//
// @author LazyBear
//
// v2 - updated the scripts to workaround function array indexing issues in the latest TV engine. 
// v1 - initial
//
study(title = "Kaufman Adaptive Moving Average [LazyBear]", shorttitle="KAMA2_LB", overlay=true)
amaLength = input(10, title="Length")
fastend=input(0.666)
slowend=input(0.0645)

diff=abs(close[0]-close[1])
signal=abs(close-close[amaLength])
noise=sum(diff, amaLength)
efratio=noise!=0 ? signal/noise : 1

smooth=pow(efratio*(fastend-slowend)+slowend,2)
kama=nz(kama[1], close)+smooth*(close-nz(kama[1], close))
plot( kama, color=green, linewidth=3)

```
