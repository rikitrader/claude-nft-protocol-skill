---
id: PUB;2603
title: Mirocana Strategy
author: pilotgsms
type: indicator
tags: []
boosts: 2149
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2603
---

# Description
Mirocana Strategy

# Source Code
```pine
//@version=2
strategy("Mirocana.com", overlay=true, currency=currency.USD, initial_capital=10000)
dt = input(defval=0.0010, title="Decision Threshold", type=float, step=0.0001)

confidence=(security(tickerid, 'D', close)-security(tickerid, 'D', close[1]))/security(tickerid, 'D', close[1])
prediction = confidence > dt ? true : confidence < -dt ? false : prediction[1]

bgcolor(prediction ? green : red, transp=93)

if (prediction)
    strategy.exit("Close", "Short")
    strategy.entry("Long", strategy.long, qty=10000*confidence)

if (not prediction)
    strategy.exit("Close", "Long")
    strategy.entry("Short", strategy.short, qty=-10000*confidence)
    
    
    
```
