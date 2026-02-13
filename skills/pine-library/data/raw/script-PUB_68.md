---
id: PUB;68
title: Ichimoku
author: HPotter
type: indicator
tags: []
boosts: 18248
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_68
---

# Description
Ichimoku

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 23/05/2014
//  Ichimoku
////////////////////////////////////////////////////////////
middleDonchian(Length) =>
    lower = lowest(Length)
    upper = highest(Length)
    avg(upper, lower)

study(title="Ichimoku2c", shorttitle="Ichimoku2c", overlay = true)
conversionPeriods = input(9, minval=1),
basePeriods = input(26, minval=1)
laggingSpan2Periods = input(52, minval=1),
displacement = input(26, minval=1)
Tenkan = middleDonchian(conversionPeriods)
Kijun =  middleDonchian(basePeriods)
xChikou = close
SenkouA = middleDonchian(laggingSpan2Periods)
SenkouB = (Tenkan[basePeriods] + Kijun[basePeriods]) / 2
plot(Tenkan, color=red, title="Tenkan")
plot(Kijun, color=blue, title="Kijun")
plot(xChikou, color= teal , title="Chikou", offset = -displacement)
A = plot(SenkouA[displacement], color=purple, title="SenkouA")
B = plot(SenkouB, color=green, title="SenkouB")
fill(A, B, color=green)
```
