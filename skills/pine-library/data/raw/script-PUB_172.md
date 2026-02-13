---
id: PUB;172
title: AK  TREND ID v1.00
author: Algokid
type: indicator
tags: []
boosts: 6572
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_172
---

# Description
AK  TREND ID v1.00

# Source Code
```pine
// AK Trend ID Version 1.00
// This indicator simply indentifies if the market are
// in a up or down trend.
// For SPX or SPY ONLY, Time Frame = Monthly
// Created by Algokid 7/23/2014 
// Toronto, Canada

study("AK_TREND ID (M)")
input1 = 3, input2 = 8 , 

fastmaa = ema(close,input1)
fastmab = ema(close,input2)

bspread = (fastmaa-fastmab)*1.001

adline = 0

m = bspread > 0 ? lime : red

plot (adline,color = white)
plot(bspread, color = m)
barcolor( bspread > 0 ? green :red)
```
