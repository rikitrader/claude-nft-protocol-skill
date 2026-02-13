---
id: PUB;1181
title: DiNapoli Detrended Oscillator Strategy
author: HPotter
type: indicator
tags: []
boosts: 482
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1181
---

# Description
DiNapoli Detrended Oscillator Strategy

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 02/04/2015
// DiNapoli Detrended Oscillator Strategy
////////////////////////////////////////////////////////////
study(title="DiNapoli Detrended Oscillator Strategy")
Length = input(14, minval=1)
Trigger = input(0)
hline(Trigger, color=gray, linestyle=line)
xSMA = sma(close, Length)
nRes = close - xSMA
pos =	iff(nRes > Trigger, 1,
	    iff(nRes <= Trigger, -1, nz(pos[1], 0))) 
plot(nRes, color=blue, title="DiNapoli")
barcolor(pos == -1 ? red: pos == 1 ? green : blue )
```
