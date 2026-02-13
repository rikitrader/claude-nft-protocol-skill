---
id: PUB;2017
title: Strategy CCT Bollinger Band Oscillator
author: Fadior
type: indicator
tags: []
boosts: 244
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2017
---

# Description
Strategy CCT Bollinger Band Oscillator

# Source Code
```pine
//@version=2
strategy(title="Strategy CCT Bollinger Band Oscillator", shorttitle="Hornkild", calc_on_order_fills=true, default_qty_type=strategy.percent_of_equity, default_qty_value=50, overlay=false)

length=input(65)
lengthMA=input(30)
src=close
cctbbo=100 * ( src + 2*stdev( src, length) - sma( src, length ) ) / ( 4 * stdev( src, length ) )

//ul=hline(100, color=gray, editable=true)
//ll=hline(0, color=gray)
//hline(50, color=gray)
//fill(ul,ll, color=blue)
//plot(cctbbo, color=blue, linewidth=2)
//plot(ema(cctbbo, lengthMA), color=red)

TP = input(0) * 10
SL = input(0) * 10
TS = input(1) * 10
TO = input(10) * 10
CQ = 100

TPP = (TP > 0) ? TP : na
SLP = (SL > 0) ? SL : na
TSP = (TS > 0) ? TS : na
TOP = (TO > 0) ? TO : na

longCondition = crossover(cctbbo, ema(cctbbo, lengthMA))
if (longCondition)
    strategy.entry("Long", strategy.long)


shortCondition = crossunder(cctbbo, ema(cctbbo, lengthMA))
if (shortCondition)
    strategy.entry("Short", strategy.short)

strategy.exit("Close Short", "Short", qty_percent=CQ, profit=TPP, loss=SLP, trail_points=TSP, trail_offset=TOP)
strategy.exit("Close Long", "Long", qty_percent=CQ, profit=TPP, loss=SLP, trail_points=TSP, trail_offset=TOP)
```
