---
id: PUB;1919
title: VWAP Stdev Bands
author: SandroTurriate
type: indicator
tags: []
boosts: 1364
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1919
---

# Description
VWAP Stdev Bands

# Source Code
```pine
study("VWAP Stdev Bands", overlay=true)
devNum = input(2, title="Number of stdev")
newSession = iff(change(dayofweek), 1, 0)
vwapsum = iff(newSession, hl2*volume, vwapsum[1]+hl2*volume)
volumesum = iff(newSession, volume, volumesum[1]+volume)
v2sum = iff(newSession, volume*hl2*hl2, v2sum[1]+volume*hl2*hl2)
myvwap = vwapsum/volumesum
dev = sqrt(max(v2sum/volumesum - myvwap*myvwap, 0))
plot(myvwap, title="VWAP")
plot(myvwap + devNum * dev, title="VWAP Upper")
plot(myvwap - devNum * dev, title="VWAP Lower")
```
