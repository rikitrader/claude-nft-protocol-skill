---
id: PUB;1714
title: MTI Stochastic RSI with Color Bars and Zones
author: FXCloud
type: indicator
tags: []
boosts: 446
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1714
---

# Description
MTI Stochastic RSI with Color Bars and Zones

# Source Code
```pine
study(title="MTI Stochastic RSI", shorttitle="MTI Stoch RSI Color Zones")
//Inputs
src = input(close, title="RSI Source")
lengthRSI = input(14,title="RSI Length", minval=1)
smoothK = input(8,title="%K", minval=1)
smoothD = input(5,title="%D", minval=1)
Overbought=input(80)
Oversold=input(20)
//RSI Calculation
rsi1 = rsi(src, lengthRSI)
//StochRSI Calculation
k=100*(rsi1-lowest(rsi1,smoothK))/(highest(rsi1,smoothK)-lowest(rsi1,smoothK))
d=sma(k, smoothD)
//StochRSI Plot
//plot(k,title="%K",color=red)
plot(d, title="%D", color=blue)
//Buy and Sell zones
h0 = hline(Overbought,title="Overbought",color=red,linestyle=solid)
h1 = hline(Oversold,title="Oversold",color=lime,linestyle=solid)
h2=hline(100,color=black)
h3=hline(0,color=black)
fill(h2,h0, color=red, transp=80)
fill(h3,h1, color=lime, transp=80)
//Bar Color
SellZone()=> d>=Overbought
BuyZone()=> d<=Oversold
barcolor(BuyZone() ? lime : SellZone() ? red : na)

```
