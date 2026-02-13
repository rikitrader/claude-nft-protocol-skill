---
id: PUB;2906
title: [NM] Reversal Candles v01
author: Profit_Through_Patience
type: indicator
tags: []
boosts: 3516
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2906
---

# Description
[NM] Reversal Candles v01

# Source Code
```pine
//  Created by Nico Muselle
study(title="[NM] Reversal Candles", shorttitle="Reversal by NM", overlay=true)


// 
ReversalLong = low[0] < low[1] and high[0] > high[1] and close[0] > low[0] + (high[0] - low[0])/2 and low[0] < low[2] and low[0] < low[3] and low[0] < low[4] and low[0] < low[5] and low[0] < low[6] and low[0] < low[7]
ReversalShort = low[0] < low[1] and high[0] > high[1] and close[0] < high[0] - (high[0] - low[0])/2 and high[0] > high[2] and high[0] > high[3] and high[0] > high[4] and high[0] > high[5] and high[0] > high[6] and high[0] > high[7]


// Bar Colors and signals
plotshape(ReversalLong,  title= "ReversalLong", location=location.belowbar, color=green, style=shape.triangleup, text="BUY")
plotshape(ReversalShort,  title= "ReversalShort", location=location.abovebar, color=red, style=shape.triangledown, text="SELL")

//bgcolor(ReversalLong ==1 ? lime : ReversalShort==1 ? red : na, transp=70)
```
