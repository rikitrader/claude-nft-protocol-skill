---
id: PUB;2949
title: Oscillator Moving Average (OsMA)
author: anexas
type: indicator
tags: []
boosts: 2046
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2949
---

# Description
Oscillator Moving Average (OsMA)

# Source Code
```pine
//Indicator - Oscillator of Moving Averages.
//Histogram of difference between MACD (oscillator) and its MA (signal line)
//Version 2.0 Created on 14 July 2016 by - Shailesh Saxena
//code based on MACD 4C indicator code published by vkno422
study(shorttitle = "OsMA", title = "Oscillator Moving Average")

//User Inputs
fastMA = input(title="Fast MA Period", type = integer, defval = 12, minval = 3)
slowMA = input(title="Slow MA Period", type = integer, defval = 26, minval = 3)
smoothing = input(title="MACD MA Period", type = integer, defval = 9, minval = 3)
sLine = input(title="Show Signal Line", type=bool, defval=true)
MACD_visible = input(title="Show MACD", type = bool, defval = true)
OsMA_histogram = input(title="Show OsMA Histogram", type = bool, defval = true)

//MACD
[MACD,signalLine,_] = macd(close[0], fastMA, slowMA, smoothing)
show_MACD = MACD_visible ? MACD : na

MACDColor = MACD > 0 
    ? MACD > MACD[1] ? lime : green 
    : MACD < MACD[1] ? red : orange
plot(show_MACD, style = line, color = MACDColor, linewidth = 1)
plot(0, title = "Zero line", linewidth = 1, color = gray)

sl = sLine ? signalLine : na
plot(sl, color = yellow, linewidth = 1)

//OsMA
OsMA = OsMA_histogram ? MACD - signalLine : na

OsMAColor = OsMA > 0 
    ? OsMA > OsMA[1] ? aqua : teal 
    : OsMA < OsMA[1] ? fuchsia : purple
plot(OsMA, style = histogram, color = OsMAColor, linewidth = 2)
plot(0, title = "Zero line", linewidth = 1, color = gray)

```
