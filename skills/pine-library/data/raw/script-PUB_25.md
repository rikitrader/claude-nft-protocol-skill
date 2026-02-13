---
id: PUB;25
title: Will this play out?
author: LazyBear
type: indicator
tags: []
boosts: 246
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_25
---

# Description
Will this play out?

# Source Code
```pine
//
// @author LazyBear
// @credits http://www.investopedia.com/terms/p/pvi.asp
// Calculation of the PVI depends on how current volume compares with the previous 
// day's trading volume. If current volume is greater than the previous day's volume, 
// PVI = Previous PVI + {[(Today's Closing Price-Yesterday's Closing Price)/Yesterday's Closing Price)] 
//   x 
// Previous PVI}. If current volume is lower than the previous day's volume, PVI is unchanged.
// 
study(title = "Positive Volume Index [LazyBear]", shorttitle="PVI_LB")

length=input(365)
showEMA=input(true, title="Show EMA?", type=bool)
START_VALUE=100
pvi=(volume > volume[1]) ? nz(pvi[1]) + ((close - close[1])/close[1]) * (na(pvi[1]) ? pvi[1] : START_VALUE) : nz(pvi[1])
hline(0)
plot(pvi)
plot(showEMA ? ema(pvi, length) : na, color=orange, linewidth=2)
```
