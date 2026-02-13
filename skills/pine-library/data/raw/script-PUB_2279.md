---
id: PUB;2279
title: ZLEMA/SMA Intersection
author: lonestar108
type: indicator
tags: []
boosts: 367
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2279
---

# Description
ZLEMA/SMA Intersection

# Source Code
```pine
//@version=2
study("ZLEMA/SMA Intersection")

len1=input(title="Enter Short  Day", type=integer, defval=1)
src1=input(close, title="Source")

ema1=ema(src1, len1)
ema2=ema(ema1, len1)
d=ema1-ema2
short=ema1+d

len2=input(title="Enter Long Day", type=integer, defval=10)
src2=input(close, title="Source")
long = sma(src2,len2)

plot(short, color = green,title="Short",style = areabr)
plot(long, color = red,title="long",style =areabr)

plot(cross(short, long) ? short : na,color=(long-short <0 ? lime:orange),style = circles, linewidth = 5,title="Intersection Point")

src = close, len = 1
out = sma(src, len)

barcolor(cross(short,long) ?  (long-short <0 ? lime:orange):na)
plotchar(cross(short,long) ? short:na , char='!', location=location.absolute, color=black,title="Alarm", text="!")

```
