---
id: PUB;426
title: Indicator: Relative Volume Indicator & Freedom Of Movement
author: LazyBear
type: indicator
tags: []
boosts: 2933
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_426
---

# Description
Indicator: Relative Volume Indicator & Freedom Of Movement

# Source Code
```pine
//
// @author LazyBear
//
// If you use this code in its orignal/modified form, do drop me a note. 
// 
study("Relative Volume Indicator [LazyBear]", shorttitle="RVI_LB")
x= input(60, "Standard deviation length")
y= input(2, "Number of deviations")
allowNegativePlots=input(false, type=bool)
matchVolumeColor=input(false, type=bool)

av= sma(volume, x)
sd= stdev(volume, x)
relVol= iff(sd!=0, (volume-av)/sd, 0)
relV = allowNegativePlots == false ? max(relVol, 0) : relVol
b_color=matchVolumeColor ? (close>open ? green : red) : black

plot(relV, style=histogram, color=relV > y ? b_color : gray, linewidth=4)


```
