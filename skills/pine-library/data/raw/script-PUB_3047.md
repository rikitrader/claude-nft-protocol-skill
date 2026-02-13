---
id: PUB;3047
title: Timezone Sessions Indicator
author: UnknownUnicorn468659
type: indicator
tags: []
boosts: 941
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_3047
---

# Description
Timezone Sessions Indicator

# Source Code
```pine
study(title="TZSes", shorttitle="Timezones Sessions")
// Timezones, Sessions
t1 = time(period, "0700-1500")
t2 = time(period, "1200-2000")
t3= time(period, "2300-0700")
trueday= time(period, "0500-0501")

TD = na(trueday) ? na: #ffffff90
London = na(t1) ? na : #ff990090
NY = na(t2) ? na : #0099ff90
Tokyo = na(t3) ? na: #cc339990

bgcolor(London, title="London")
bgcolor(NY, title="New York")
bgcolor(Tokyo, title="Tokyo")
bgcolor(TD, title="True Day")
```
