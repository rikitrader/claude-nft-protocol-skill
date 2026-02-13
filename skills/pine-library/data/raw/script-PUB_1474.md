---
id: PUB;1474
title: RSI Stochastic Extreme Combo alert
author: repo32
type: indicator
tags: []
boosts: 2748
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1474
---

# Description
RSI Stochastic Extreme Combo alert

# Source Code
```pine
//Created by Robert Nance on 6/26/15
//This script will give you red or green columns as an indication for oversold/overbought based
//upon the rsi and stochastic both being at certain levels. The default oversold is at 35.  If Stochastic
//and RSI fall below 35, you will get a green column.  Play with your levels to see how your stock reacts.

study(title="RSI Stochastic Combo alert", shorttitle="Rob RSI Stoch")

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
plot(Buy,  title= "Buy", style=columns, color=lime)
plot(Sell,  title= "Sell", style=columns, color=red)

```
