---
id: PUB;4225
title: ENGULFING CANDLESTICK STRATEGY
author: SimpleTradingTechniques
type: indicator
tags: []
boosts: 665
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_4225
---

# Description
ENGULFING CANDLESTICK STRATEGY

# Source Code
```pine
//  By SIMPLE TRADING TECHNIQUES

//   	Arrow represent trade setup 
//   	Circle represent triggering of the trade
//--------------------------------------------------------------------

study(title="STT ENGULFING CANDLESTICK STRATEGY",overlay = true, shorttitle="STT ECS")
src = close, len = input(8, minval=1, title="Length")
up = rma(max(change(src), 0), len)
down = rma(-min(change(src), 0), len)
rsi = down == 0 ? 100 : up == 0 ? 0 : 100 - (100 / (1 + up / down))

//coloring method below

src1 = close, len1 = input(50, minval=1, title="UpLevel")
src2 = close, len2 = input(50, minval=1, title="DownLevel")
isup() => rsi > len1
isdown() => rsi < len2
barcolor(isup() ? green : isdown() ? red : na )

//study('buy/sell arrows', overlay=true)

out = sma(close, 50)
data = rsi > len1 ? open[1] > close[1] ? close > open ? close >= open[1] ? close[1] >= open ? close - open > open[1] - close[1] ? high > out : na : na : na : na : na : na
data1 = rsi < len2 ? close[1] > open[1] ? open > close ? open >= close[1] ? open[1] >= close ? open - close > close[1] - open[1] ? low < out : na : na : na : na : na : na


plotchar(data, char='↑',location=location.belowbar, color=lime, text="ECS Buy")
plotchar(data1, char='↓', location=location.abovebar, color=red, text="ECS Sell")

//Trade Trigger
tiggerlongcandle = (data[1] == 1) and (high > high[1]) ? 1 : 0
tiggershortcandle = (data1[1] == 1) and (low < low[1]) ? 1 : 0
plotshape(tiggerlongcandle ? tiggerlongcandle : na, title="Triggered Long",style=shape.circle, location=location.belowbar, color=green, transp=0, offset=0, text="ECS")
plotshape(tiggershortcandle ? tiggershortcandle : na, title="Triggered Short",style=shape.circle, location=location.abovebar, color=red, transp=0, offset=0, text="ECS")

plot (out, color = black, linewidth = 3, title = "Trend - Long Term")

```
