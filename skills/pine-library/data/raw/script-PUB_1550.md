---
id: PUB;1550
title: 4 colour MACD with signal line
author: vkno422
type: indicator
tags: []
boosts: 1110
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1550
---

# Description
4 colour MACD with signal line

# Source Code
```pine
study(shorttitle = "MACD 4CS", title = "4 colour MACD with signal line")
fastMA = input(title="Fast moving average", type = integer, defval = 12, minval = 7)
slowMA = input(title="Slow moving average", type = integer, defval = 26, minval = 7)
signalIn = input(title="Signal period", type = integer, defval = 9, minval = 3)
lastColor = yellow
[currMacd,currSignal,_] = macd(close[0], fastMA, slowMA, signalIn)
[prevMacd,prevSignal,_] = macd(close[1], fastMA, slowMA, signalIn)
plotColor = currMacd > 0 
    ? currMacd > prevMacd ? lime : green 
    : currMacd < prevMacd ? maroon : red
plot(currMacd, style = histogram, color = plotColor, linewidth = 3)
plot(currSignal, style = line, color = aqua, linewidth = 1)
plot(0, title = "Zero line", linewidth = 1, color = gray)

```
