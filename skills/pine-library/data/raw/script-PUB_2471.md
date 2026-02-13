---
id: PUB;2471
title: Oscars Simple Trend Ichimoku Kijun-sen
author: CapnOscar
type: indicator
tags: []
boosts: 1295
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2471
---

# Description
Oscars Simple Trend Ichimoku Kijun-sen

# Source Code
```pine
study(title="Oscars Simple Trend Ichimoku Kijun-sen", shorttitle="OTrend Kijun", overlay=true)

Length = input(34, minval=1)
Trigger = input(5, minval=1),



donchian(len) => avg(lowest(len), highest(len))

conversionLine = donchian(Trigger)
baseLine = donchian(Length)
leadLine1 = avg(conversionLine, baseLine)

kjuncol = conversionLine > baseLine ? blue : conversionLine < baseLine ? red : orange


plot(baseLine, color=kjuncol,linewidth=2,transp=5, title="Base Line")

almatrend = alma(baseLine, 34, 0.85, 6)

plot(almatrend,transp=85)

```
