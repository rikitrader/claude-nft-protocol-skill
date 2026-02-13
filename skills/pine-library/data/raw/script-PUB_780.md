---
id: PUB;780
title: LX Rsi Divergence Bars
author: lix
type: indicator
tags: []
boosts: 794
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_780
---

# Description
LX Rsi Divergence Bars

# Source Code
```pine
study("LX Rsi Divergence Bars", shorttitle="LiX_RSIBARS", overlay=true)
//r = rising(ohlc4,6)
//rb = close + highestbars(close,6)
rsiperiod = input(title="RSI Period", type=integer, defval=21)
overb = input(title="Overbought", type=integer, defval=70)
oversold = input(title="Oversold", type=integer, defval=30)
rsbar = rsi(close,rsiperiod)
//clr = rsbar > 60 ? open < close ? 4 : na : na
//plot(clr,title="200 price",color=#3399FF,transp=90)
//bgcolor(close < open ? red : green, transp=70)
//barcolor(close < open ? silver : #3C78D8)
barcolor(rsbar >= overb ? open < close ? green : na : na) // moves in the trend of overbought
barcolor(rsbar >= overb ? open > close ? red : na : na) // diverging bar

barcolor(rsbar <= oversold ? open < close ? green : na : na) // diverging bar
barcolor(rsbar <= oversold ? open > close ? gray : na : na) // moves in the trend of oversold
```
