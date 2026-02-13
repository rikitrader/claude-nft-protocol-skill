---
id: PUB;1297
title: MACD DEUTERANOPIE
author: cfhrtd
type: indicator
tags: []
boosts: 645
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1297
---

# Description
MACD DEUTERANOPIE

# Source Code
```pine
study(shorttitle = "MACD DEUTER", title = "4 colour MACD")
fastMA = input(title="Fast moving average", type = integer, defval = 12, minval = 7)
slowMA = input(title="Slow moving average", type = integer, defval = 26, minval = 7)
lastColor = yellow
[currMacd,_,_] = macd(close[0], fastMA, slowMA, 9)
[prevMacd,_,_] = macd(close[1], fastMA, slowMA, 9)
plotColor = currMacd > 0 
    ? currMacd > prevMacd ? aqua : navy 
    : currMacd < prevMacd ? maroon : red
plot(currMacd, style = histogram, color = plotColor, linewidth = 3)
plot(0, title = "Zero line", linewidth = 1, color = gray)

```
