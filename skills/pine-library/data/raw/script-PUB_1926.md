---
id: PUB;1926
title: Simple RSI-MA Algo Beats DOW By Huge Margin Over Past 100 Years!
author: Stable_Camel
type: indicator
tags: []
boosts: 3312
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1926
---

# Description
Simple RSI-MA Algo Beats DOW By Huge Margin Over Past 100 Years!

# Source Code
```pine
//@version=2
strategy("RSI-MA Algo", overlay=true)
price = close

basis = rsi(close, input(10))

sma1 = sma(basis, input(50))
sma2 = sma(basis, input(50))

oversold = input(30)
overbought = input(70)

if (crossover(sma1, 50))
    strategy.entry("MA2CrossLE", strategy.long, comment="BUY")

if (crossunder(sma2, 50))
    strategy.entry("MA2CrossSE", strategy.short, comment="SELL")

//plot(strategy.equity, title="equity", color=red, linewidth=2, style=areabr)
```
