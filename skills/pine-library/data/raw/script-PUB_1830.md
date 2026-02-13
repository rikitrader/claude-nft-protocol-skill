---
id: PUB;1830
title: 50% body candle
author: Eminaest
type: indicator
tags: []
boosts: 3785
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1830
---

# Description
50% body candle

# Source Code
```pine
//Colors candles with body less than 50% of range of candle
study(title = "<50% body candle", overlay = true)

candr = high-low
bodyr = open-close

borat = (bodyr*100/candr)

barcolor (borat>-50 and borat <50 ? white : na)
```
