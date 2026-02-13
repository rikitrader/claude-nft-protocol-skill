---
id: PUB;2564
title: MACDouble + RSI (rec. 15min-2hr intrv)
author: RyanMartin
type: indicator
tags: []
boosts: 548
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2564
---

# Description
MACDouble + RSI (rec. 15min-2hr intrv)

# Source Code
```pine
//@version=2
strategy("MACDbl RSI", overlay=true)

fastLength = input(10)
slowlength = input(22)
MACDLength = input(9)

MACD = ema(close, fastLength) - ema(close, slowlength)
aMACD = sma(MACD, MACDLength)
delta = MACD - aMACD

fastLength2 = input(21)
slowlength2 = input(45)
MACDLength2 = input(20)

MACD2 = ema(open, fastLength2) - ema(open, slowlength2)
aMACD2 = sma(MACD2, MACDLength2)
delta2 = MACD2 - aMACD2

Length = input(14, minval=1)
Oversold = input(20, minval=1)
Overbought = input(70, minval=1)
xRSI = rsi(open, Length)


if (delta > 0) and (year>2015) and (delta2 > 0) and (xRSI < Overbought)
    strategy.entry("buy", strategy.long, comment="buy")

if (delta < 0) and (year>2015) and (delta2 < 0) and (xRSI > Oversold)
    strategy.entry("sell", strategy.short, comment="sell")

//plot(strategy.equity, title="equity", color=red, linewidth=2, style=areabr)
```
