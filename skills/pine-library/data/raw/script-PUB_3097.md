---
id: PUB;3097
title: Single SMA cross with BB Strategy
author: forexpirate
type: indicator
tags: []
boosts: 482
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_3097
---

# Description
Single SMA cross with BB Strategy

# Source Code
```pine
//@version=2
strategy(title="single sma cross", shorttitle="single sma cross",default_qty_type = strategy.percent_of_equity, default_qty_value = 100,overlay=true,currency="USD")
s=input(title="s",defval=90,type=integer)
p=input(title="p",type=float,defval=.9,step=.1)

sa=sma(close,s)
plot(sa,color=red,linewidth=3)
band=stdev(close,s)*p
plot(band+sa,color=lime,title="")
plot(-band+sa,color=lime,title="")

// ===Strategy Orders============================================= ========
inpTakeProfit = input(defval = 0, title = "Take Profit", minval = 0)
inpStopLoss = input(defval = 0, title = "Stop Loss", minval = 0)
inpTrailStop = input(defval = 0, title = "Trailing Stop Loss", minval = 0)
inpTrailOffset = input(defval = 0, title = "Trailing Stop Loss Offset", minval = 0)
useTakeProfit = inpTakeProfit >= 1 ? inpTakeProfit : na
useStopLoss = inpStopLoss >= 1 ? inpStopLoss : na
useTrailStop = inpTrailStop >= 1 ? inpTrailStop : na
useTrailOffset = inpTrailOffset >= 1 ? inpTrailOffset : na

longCondition = crossover(close,sa+band) and rising(sa,5)
shortCondition = crossunder(close,sa-band) and falling(sa,5)
crossmid = cross(close,sa)


strategy.entry(id = "Long", long=true, when = longCondition)
strategy.close(id = "Long", when = shortCondition)
strategy.entry(id = "Short", long=false, when = shortCondition)
strategy.close(id = "Short", when = longCondition)
strategy.exit("Exit Long", from_entry = "Long", profit = useTakeProfit, loss = useStopLoss, trail_points = useTrailStop, trail_offset = useTrailOffset, when=crossmid)
strategy.exit("Exit Short", from_entry = "Short", profit = useTakeProfit, loss = useStopLoss, trail_points = useTrailStop, trail_offset = useTrailOffset, when=crossmid)
```
