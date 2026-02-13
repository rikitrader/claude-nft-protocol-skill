---
id: PUB;670
title: Steve Primo's "Robbery" Indicator (PET-D)
author: UDAY_C_Santhakumar
type: indicator
tags: []
boosts: 3110
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_670
---

# Description
Steve Primo's "Robbery" Indicator (PET-D)

# Source Code
```pine
//Created by UCSgears, Found PET-D Indicator for sale and Subscription via youtube
// Link : http://www.protraderstrategies.com/primo-early-trend-detector-pet-d/pet-d-members-area/

study(title="Steven Primo's PET-D", shorttitle="Pet-D", overlay=true)

petd = ema(close, 15)
up = close > petd ? green : red

barcolor(up)
```
