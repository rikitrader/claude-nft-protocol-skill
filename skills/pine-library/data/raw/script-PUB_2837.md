---
id: PUB;2837
title: Daily Candle Cross
author: SeaSide420
type: indicator
tags: []
boosts: 1299
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2837
---

# Description
Daily Candle Cross

# Source Code
```pine
//@version=2
//                     simple cross of daily candle close
//
strategy("DailyCandleCross", shorttitle="DCC", overlay=true, calc_on_order_fills= true, calc_on_every_tick=true, default_qty_type=strategy.percent_of_equity, default_qty_value=75, pyramiding=0)
A=security(tickerid, 'D', close)
B=security(tickerid, 'D', close[1])
C=A>B
if(C)
    strategy.entry("Long", strategy.long)
if(not C)
    strategy.entry("Short", strategy.short)
```
