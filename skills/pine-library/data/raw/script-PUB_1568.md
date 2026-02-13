---
id: PUB;1568
title: Trailing Sharpe Ratio
author: Rashad
type: indicator
tags: []
boosts: 773
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1568
---

# Description
Trailing Sharpe Ratio

# Source Code
```pine
study("Trailing Sharpe Ratio")
src = ohlc4, len = input(252, title = "Time Frame (252 is one year)")
//mean = sma(src,len)
dividend_yield = input(0.0000, minval = 0.00001, title = "Dividend Yield? Enter as Decimal, USE 12 MONTH TTM!!!")
pc = ((src - src[len])/src) + (dividend_yield*(len/252))
std = stdev(src,len)
stdaspercent = std/src
riskfreerate = input(0.0004, minval = 0.0001, title = "risk free rate (3 month treasury yield), enter as decimal")
sharpe = (pc - riskfreerate)/stdaspercent
signal = sma(sharpe,len)
calc = sharpe - signal
plot(sharpe, style = line, color = calc < 0 ? red : green, linewidth = 2)
plot(signal, style = line, color = purple, linewidth = 2)
```
