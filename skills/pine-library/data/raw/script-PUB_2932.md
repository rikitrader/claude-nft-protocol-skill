---
id: PUB;2932
title: The Always Winning Holy Grail Strategy - Not (by ChartArt)
author: ChartArt
type: indicator
tags: []
boosts: 2342
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2932
---

# Description
The Always Winning Holy Grail Strategy - Not (by ChartArt)

# Source Code
```pine
//@version=2
strategy("The Always Winning Holy Grail Strategy - Not (by ChartArt)", shorttitle="CA_-_Not_The_Holy_Grail_Strat", pyramiding = 0, overlay=true)

// Strategy entry condition:
if 1+1 == 2   // go long if 1+1 = 2
    strategy.entry("long", strategy.long, comment="long", qty = 10)


// Money management of the strategy:
TakeProfit = input(100,step=25)
StopLoss = input(999999999999999,step=999999999999999)


// Strategy exit condition: (always take profit and use a super extreme ridiculous wide stop loss)
strategy.exit("exit", "long", profit = TakeProfit, loss = StopLoss)
```
