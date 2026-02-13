---
id: PUB;672
title: Ichimoku Cloud ALERT
author: Tracha
type: indicator
tags: []
boosts: 4000
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_672
---

# Description
Ichimoku Cloud ALERT

# Source Code
```pine
study(title="Ichimoku Cloud", shorttitle="Ichimoku", overlay=true)

conversionPeriods = input(9, minval=1),
basePeriods = input(26, minval=1)
laggingSpan2Periods = input(52, minval=1)
EMAno1 = input(21, minval=1)
EMAno2 = input(144, minval=1)
EMAno3 = input(377, minval=1)
displacement = basePeriods

donchian(len) => avg(lowest(len), highest(len))

conversionLine = donchian(conversionPeriods)
baseLine = donchian(basePeriods)
leadLine1 = avg(conversionLine, baseLine)
leadLine2 = donchian(laggingSpan2Periods)

plot(conversionLine, color=red, title="Conversion Line")
plot(baseLine, color=blue, title="Base Line")
plot(close, offset = -displacement, color=green, title="Lagging Span")

p1 = plot(leadLine1, offset = displacement, color=green,
    title="Lead 1")
p2 = plot(leadLine2, offset = displacement, color=red, 
    title="Lead 2")

ema1=ema(close,EMAno1)
ema2=ema(close,EMAno2)
ema3=ema(close,EMAno3)

//sell signals
signal1 = baseLine > conversionLine

signal2 = close <= ema1
signal2a = close <= ema2
signal2b = close <= ema3

bottomcloud=leadLine2[displacement-1]
uppercloud=leadLine1[displacement-1]

signal3 = close<bottomcloud
signal3a = close[1]>bottomcloud[1]
signal3b = bottomcloud<uppercloud

signal4 = close<low[displacement]

plotchar(signal1 and signal2 and signal2a and signal2b and signal3 and signal3a and signal3b and signal4, char='S', color=red, location=location.abovebar)

signal3x = close<uppercloud
signal3ax = close[1]>uppercloud[1]
signal3bx = bottomcloud>uppercloud
plotchar(signal1 and signal2 and signal2a and signal2b and signal3x and signal3ax and signal3bx and signal4, char='S', color=red, location=location.abovebar)



/// buy signals
nsignal1 = baseLine < conversionLine

nsignal2 = close >= ema1
nsignal2a = close >= ema2
nsignal2b = close >= ema3

nsignal3 = close>uppercloud
nsignal3a = close[1]<uppercloud[1]
nsignal3b = bottomcloud<uppercloud

nsignal4 = close>high[displacement]

plotchar(nsignal1 and nsignal2 and nsignal2a and nsignal2b and nsignal3 and nsignal3a and signal3b and nsignal4, char='B', color=blue, location=location.belowbar)

nsignal3x = close>uppercloud
nsignal3ax = close[1]<uppercloud[1]
nsignal3bx = bottomcloud<uppercloud

plotchar(nsignal1 and nsignal2 and nsignal2a and nsignal2b and nsignal3x and nsignal3ax and signal3bx and nsignal4, char='B', color=blue, location=location.belowbar)

fill(p1, p2)

```
