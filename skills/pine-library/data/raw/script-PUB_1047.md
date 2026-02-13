---
id: PUB;1047
title: Moving Average Rate Of Change
author: IldarAkhmetgaleev
type: indicator
tags: []
boosts: 1230
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1047
---

# Description
Moving Average Rate Of Change

# Source Code
```pine
study(title="Moving Average Rate Of Change", shorttitle="MAROC")
sma_len = input(21, minval=1, title="SMA len")
roc_len = input(5, minval=1, title="ROC len")
src = close

smooth = sma(src, sma_len)
sma_roc = 100 * (smooth - smooth[roc_len])/smooth[roc_len]
color = sma_roc > sma_roc[roc_len] ? green : red

plot(sma_roc, color=color, title="SMA ROC", style=line)
hline(0)
```
