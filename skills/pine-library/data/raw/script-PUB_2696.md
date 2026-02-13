---
id: PUB;2696
title: Rob RSI Stoch MACD  Combo Alert
author: repo32
type: indicator
tags: []
boosts: 1423
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2696
---

# Description
Rob RSI Stoch MACD  Combo Alert

# Source Code
```pine
//Created by Robert Nance on 5/28/16. Additional credit to vdubus.
//This was a special request from rich15stan.  It combines my original RSI Stoch extremes with vdubus’ MACD VXI.  
//This script will give you red or green columns as an indication for oversold/overbought, 
//based upon the rsi and stochastic both being at certain levels. The default oversold is at 35.  
//If Stochastic and RSI fall below 35, you will get a green column.  Play with your levels to see how 
//your stock reacts.  It now adds the MACD crossover, plotted as a blue circle.

study(title="Rob RSI StochMACD  Combo Alert", shorttitle="Rob RSI StochMACD")

src = close, len = input(14, minval=1, title="RSI Length")
up = rma(max(change(src), 0), len)
down = rma(-min(change(src), 0), len)
rsi = down == 0 ? 100 : up == 0 ? 0 : 100 - (100 / (1 + up / down))

length = input(14, minval=1, title="Stoch Length"), smoothK = input(1, minval=1, title="Stoch K")
k = sma(stoch(close, high, low, length), smoothK)

rsilow = input(35, title="rsi Low value")
rsihigh = input(65, title="rsi High value")
stochlow = input(35, title="stochastic Low value")
stochhigh = input(65, title="stochastic High value")
Buy=rsi<rsilow and k<stochlow
Sell=rsi>rsihigh and k>stochhigh

fastLength = input(13, minval=1,title="MACD Fast Length")
slowLength = input(21,minval=1,title="MACD Slow Length")
signalLength = input(8,minval=1,title="MACD Signal Length")
fastMA = ema(src, fastLength)
slowMA = ema(src, slowLength)
macd = fastMA - slowMA
signal = sma(macd, signalLength)

plot(Buy,  title= "Buy", style=columns, color=lime)
plot(Sell,  title= "Sell", style=columns, color=red)
plot(cross(signal, macd) ? signal*0+.5 : na, color=blue, style = circles, linewidth = 4)

```
