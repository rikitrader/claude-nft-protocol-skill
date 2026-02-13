---
id: PUB;457
title: Momentum Histogram
author: UDAY_C_Santhakumar
type: indicator
tags: []
boosts: 595
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_457
---

# Description
Momentum Histogram

# Source Code
```pine

study(title = "Momentum Histogram", shorttitle="Mom Hist")

source=close
EMA_1=input(13, title="EMA 1")
EMA_2=input(21, title="EMA 2")
EMA_3=input(34, title="EMA 3")

hist1 = (ema(close,EMA_1)*close)-(ema(close,EMA_2)*close)
hist2 = (ema(close,EMA_2)*close)-(ema(close,EMA_3)*close)

Wave1=(hist1)
Wave2=(hist2)

plot(Wave2, style=histogram, color=red, linewidth=4)
plot(Wave1, style=histogram, color=#0066cc, linewidth=4)
```
