---
id: PUB;1263
title: KK_Price Action Channel (TDI BH)
author: Kurbelklaus
type: indicator
tags: []
boosts: 1578
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1263
---

# Description
KK_Price Action Channel (TDI BH)

# Source Code
```pine
//author: Kurbelklaus
//Code for the smoothed moving average taken from the public library
study(title = "KK_Price Action Channel", shorttitle="PAC", overlay=true)
srcH = high
srcL = low
lenH = input(5, minval=1, title="Length High")
lenL = input(5, minval=1, title="Length Low")
smmaH = na(smmaH[1]) ? sma(srcH, lenH) : (smmaH[1] * (lenH - 1) + srcH) / lenH
smmaL = na(smmaL[1]) ? sma(srcL, lenL) : (smmaL[1] * (lenL - 1) + srcL) / lenL
plot(smmaH, color=blue)
plot(smmaL, color=blue)
```
