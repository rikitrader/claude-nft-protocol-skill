---
id: PUB;1643
title: Outside Reversal SetUp
author: cristian.d
type: indicator
tags: []
boosts: 1770
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1643
---

# Description
Outside Reversal SetUp

# Source Code
```pine
//  Created by Cristian.D - from Secrets of a Pivot Boss - Frank Ochoa
study(title="OutsideReversal", shorttitle="OReversal", overlay=true)

// 
ReversalLong = low < low[1] and close > high[1]  and open <close[1]
ReversalShort = high > high[1] and close < low[1] and open >open[1]



// Bar Colors and signals
plotshape(ReversalLong,  title= "ReversalLong", location=location.belowbar, color=lime, style=shape.arrowup, text="BUY")
plotshape(ReversalShort,  title= "ReversalShort", location=location.abovebar, color=red, style=shape.arrowdown, text="SELL")

bgcolor(ReversalLong ==1 ? lime : ReversalShort==1 ? red : na, transp=70)







```
