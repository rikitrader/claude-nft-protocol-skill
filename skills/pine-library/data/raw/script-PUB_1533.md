---
id: PUB;1533
title: SFX Trend or Range
author: whis_gg
type: indicator
tags: []
boosts: 1760
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1533
---

# Description
SFX Trend or Range

# Source Code
```pine
study(title="SFX Trend or Range", shorttitle="SFX TOR")

ATR_len = input(12, title="ATR Length")
StdDev_len = input(12, title="StdDev Length")
SMA_len = input(3, title="SMA Length")


ATR = atr(ATR_len)
StdDev = stdev(close, StdDev_len)
SMA = sma(StdDev, SMA_len)


plot(ATR, linewidth=2, color=aqua, title="ATR")
plot(StdDev, color=orange, title="StdDev")
plot(SMA, color=red, title="SMA")
```
