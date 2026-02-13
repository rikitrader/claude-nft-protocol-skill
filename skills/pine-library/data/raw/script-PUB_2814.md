---
id: PUB;2814
title: VWAP Candles
author: TheYangGuizi
type: indicator
tags: []
boosts: 2849
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2814
---

# Description
VWAP Candles

# Source Code
```pine
study(title="VWAP Candles", shorttitle="VWAP Candles", overlay=true)


//------------------------------------------------

//------------------------------------------------
NormalVwap=vwap(hlc3)
H = vwap(high)
L = vwap(low)
O = vwap(open)
C = vwap(close)

left = input(title="# bars to the left", type=integer, defval=30)

left_low = lowest(left)
left_high = highest(left)
newlow = low <= left_low
newhigh = high >= left_high

q = barssince(newlow)
w = barssince(newhigh)
col2 = q < w ?  #8B3A3A : #9CBA7F
col2b=O > C?red:lime


AVGHL=avg(H,L)
AVGOC=avg(O,C)
col=AVGHL>AVGOC?lime:red
col3=open > AVGOC?lime:red
plotcandle(O,H,L,C,color=col2b)
//plot(H, title="VWAP", color=red)
//plot(L, title="VWAP", color=lime)
//plot(O, title="VWAP", color=blue)
//plot(C, title="VWAP", color=black)

plot(NormalVwap, color=col2b)
```
