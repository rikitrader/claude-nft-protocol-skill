---
id: PUB;923
title: strategy MACD and RSI alert fixed
author: munsifk
type: indicator
tags: []
boosts: 559
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_923
---

# Description
strategy MACD and RSI alert fixed

# Source Code
```pine

////////////////////////////////////////////////////////////
study(title="Strategy MACD and RSI alert", shorttitle="Strategy MACD and RSI alert", overlay = false )
fastLength = input(8, minval=1)
slowLength = input(16,minval=1)
signalLength=input(11,minval=1)
hline(0, color=purple, linestyle=dashed)
fastMA = ema(close, fastLength)
slowMA = ema(close, slowLength)
macd = fastMA - slowMA
signal = sma(macd, signalLength)

Length = input(10, minval=1)
Oversold = input(49, minval=1)
Overbought = input(51, minval=1)
xRSI = rsi(close, Length)



pos = iff(xRSI > Overbought and signal < macd, 1,
        iff(xRSI < Oversold and signal > macd, -1, nz(pos[1], 0))) 
        
poschange = (pos[1] == -1 and pos == 1) or (pos[1] == 1 and pos == -1 ) ? 1 : 0  
barcolor(pos == -1 ? red: pos == 1 ? green : blue)

//plot(pos, title="pos", style=line, linewidth=1, color=red )
plot(poschange, title="change of colour alert", style=line, linewidth=1, color=yellow )
```
