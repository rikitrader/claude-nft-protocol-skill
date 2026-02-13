---
id: PUB;144
title: 3-Bar-Reversal-Pattern Strategy
author: HPotter
type: indicator
tags: []
boosts: 1851
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_144
---

# Description
3-Bar-Reversal-Pattern Strategy

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 24/06/2014
// This startegy based on 3-day pattern reversal described in "Are Three-Bar 
// Patterns Reliable For Stocks" article by Thomas Bulkowski, presented in 
// January,2000 issue of Stocks&Commodities magazine.
// That pattern conforms to the following rules:
// - It uses daily prices, not intraday or weekly prices;
// - The middle day of the three-day pattern has the lowest low of the three days, with no ties allowed;
// - The last day must have a close above the prior day's high, with no ties allowed;
// - Each day must have a nonzero trading range. 
////////////////////////////////////////////////////////////
study(title="3-Bar-Reversal-Pattern Strategy", shorttitle="3-Bar-Reversal-Pattern Strategy", overlay = true)
pos =	iff(open[2] > close[2] and high[1] < high[2] and low[1] < low[2] and low[0] > low[1] and high[0] > high[1], 1,
	    iff(open[2] < close[2] and high[1] > high[2] and low[1] > low[2] and high[0] < high[1] and low[0] < low[1], -1, nz(pos[1], 0))) 
barcolor(pos == -1 ? red: pos == 1 ? green : blue )

```
