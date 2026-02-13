---
id: PUB;687
title: Heiken Ashi Ichimoku
author: Tracha
type: indicator
tags: []
boosts: 3666
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_687
---

# Description
Heiken Ashi Ichimoku

# Source Code
```pine
study(title="Ichimoku Cloud", shorttitle="Ichimoku", overlay=true)

conversionPeriods = input(9, minval=1),
basePeriods = input(26, minval=1)
laggingSpan2Periods = input(52, minval=1),
displacement = basePeriods

donchian(len) => avg(lowest(len), highest(len))

conversionLine = donchian(conversionPeriods)
baseLine = donchian(basePeriods)
leadLine1 = avg(conversionLine, baseLine)
leadLine2 = donchian(laggingSpan2Periods)

plot(conversionLine, color=blue, title="Conversion Line")
plot(baseLine, color=red, title="Base Line")


p1 = plot(leadLine1, offset = displacement, color=green,
    title="Lead 1")
p2 = plot(leadLine2, offset = displacement, color=red, 
    title="Lead 2")
fill(p1, p2)

plot(sma(close,55), color=yellow, title='Simple Moving Average')
distance = abs(open - sma(close,55))

signal1 = close < conversionLine
signal2 = conversionLine > baseLine
signal3 = close < leadLine1 and close < leadLine2
signal4 = close < sma(close,55)
signal5 = distance < abs(highest(20) - lowest(20))/3
signal6 = open[1]<close[1]

SELLSIGNAL = signal1 and signal2 and signal3 and signal4 and signal5 and signal6
barcolor(SELLSIGNAL ? yellow:na)

signal1b = close > conversionLine
signal2b = conversionLine < baseLine
signal3b = close > leadLine1 and close > leadLine2
signal4b = close > sma(close,55)
signal5b = distance < abs(highest(20) - lowest(20))/3
signal6b = open[1]>close[1]

BUYSIGNAL = signal1b and signal2b and signal3b and signal4b and signal5b and signal6b
barcolor(BUYSIGNAL ? blue:na)
```
