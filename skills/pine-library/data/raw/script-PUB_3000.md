---
id: PUB;3000
title: SMA for each time period
author: forexpirate
type: indicator
tags: []
boosts: 954
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_3000
---

# Description
SMA for each time period

# Source Code
```pine
//@version=2
study("SMA for each time period",overlay=true)
s = (period == "1"  ?144: period == "2"  ? 89: period == "15" ? 54:period == "60" ? 34:period == "D" ? 21:100)
f = (period == "1"  ?88: period == "2"  ? 54: period == "15" ? 34:period == "60" ? 21:period == "D" ? 13:100)
q = (period == "60" ? 1506:period == "D" ? 63:0)

plot(sma(close,f),color=aqua,linewidth=3,transp=0,title="Fast")
plot(sma(close,s),color=white,linewidth=3,transp=0,title="Slow")
plot(sma(close,q),color=yellow,linewidth=3,transp=0,title="Quarter")
```
