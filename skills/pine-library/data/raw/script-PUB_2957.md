---
id: PUB;2957
title: ZONE Supply Demand Strategy1
author: MarxBabu
type: indicator
tags: []
boosts: 3368
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2957
---

# Description
ZONE Supply Demand Strategy1

# Source Code
```pine
//@version=2
study("ZONE",overlay=false)
len = input(35,title="Period")
smooth = input(100,title="Smooth")

plotcandle(open, high, low, close, title='candle', color=(open < close) ? green : red, wickcolor=gray)
// This is working isHigherHigh() => high>high[1] and high[1]>high[2] and low>low[1] and low[1]>low[2]  and close>close[1] and high>close and close>high[1] and close>low[1] and close>(open and low) and close[1]>(open[1]and low[1])and close[2]>(open[2]and low[2]) 
isHigherHigh() => high>high[1] and high[1]>high[2] and close>close[1] and close[1]>close[2] and close>open and close[1]>open[1] and close[2]>open[2] and low>open[1] and low[1]>open[2] and (open+low)<(open+close) //and low>ohlc4[1] and low[1]>ohlc4[2]   //and low>open[1] and low[1]>open[2] this code is to make sure low not below open of before candle

barcolor(isHigherHigh()? black :na)
barcolor(isHigherHigh()? black :na, -1)
barcolor((isHigherHigh() and close>open)? black :na, -2)
    
//barcolor()


```
