---
id: PUB;53
title: TFS: Volume Oscillator 
author: HPotter
type: indicator
tags: []
boosts: 1169
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_53
---

# Description
TFS: Volume Oscillator 

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 16/06/2014
// This is the second part of TFS trading strategy. The concept of this 
// indicator is similar to that of On-Balance Volume indicator (OBV). It 
// is calculated according to these rules:
// If Close > Open, Volume is positive
// If Close < Open, Volume is negative
// If Close = Open, Volume is neutral
// Then you take the 7-day MA of the results. 
////////////////////////////////////////////////////////////
study(title="TFS: Volume Oscillator", shorttitle="TFS: Volume Oscillator")
AvgLen = input(7, minval=1)
hline(0, color=red, linestyle=line)
xClose = close
xOpen = open
xVolume = volume
nVolAccum = sum(iff(xClose > xOpen, xVolume, iff(xClose < xOpen, -xVolume, 0))  ,AvgLen)
nRes = nVolAccum / AvgLen
plot(nRes, color=blue, title="TFS", style = histogram)

```
