---
id: PUB;2276
title: SMA Intersection Enhanced
author: lonestar108
type: indicator
tags: []
boosts: 766
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2276
---

# Description
SMA Intersection Enhanced

# Source Code
```pine
//@version=2
study("SMA Intersection Enhanced")

len1=input(title="Enter Short  Day", type=integer, defval=1)
src1=input(close, title="Source")
short = sma(src1,len1)

len2=input(title="Enter Long Day", type=integer, defval=9)
src2=input(close, title="Source")
long = sma(src2,len2)

plot(short, color = green,title="Short",style = areabr)
plot(long, color = red,title="long",style =areabr)

plot(cross(short, long) ? short : na,color=(long-short <0 ? lime:orange),style = circles, linewidth = 5,title="İntersection Point")

src = close, len = 1
out = sma(src, len)

barcolor(cross(short,long) ?  (long-short <0 ? lime:orange):na)
plotchar(cross(short,long) ? short:na , char='!', location=location.absolute, color=black,title="Alarm", text="!")

```
