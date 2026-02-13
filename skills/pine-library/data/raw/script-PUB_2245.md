---
id: PUB;2245
title: Commodity Channel Index/RSI
author: matt5151
type: indicator
tags: []
boosts: 463
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2245
---

# Description
Commodity Channel Index/RSI

# Source Code
```pine
study(title="Commodity Channel Index/RSI", shorttitle="CCI/RSI")

length1 = input(14, minval=1)
length2 = input(5, minval=1)

src = input(close, title="Source")

ma = sma(src, length1)
ma2 = sma(src, length2)

cci = (src - ma) / (0.015 * dev(src, length1))
cci2 = (src - ma) / (0.015 * dev(src, length2))

up14 = rma(max(change(src), 0), length1)
down14 = rma(-min(change(src), 0), length1)
up5 = rma(max(change(src), 0), length2)
down5 = rma(-min(change(src), 0), length2)
rsi5 = down5 == 0 ? 100 : up5 == 0 ? 0 : 100 - (100 / (1 + up5 / down5))
rsi14 = down14 == 0 ? 100 : up14 == 0 ? 0 : 100 - (100 / (1 + up14 / down14))
//CCI here
plot(cci, color=green,linewidth=2,title = "cci-14")
plot(cci2, color=green,linewidth=2,title = "cci-5")
//RSI here
plot(rsi14, color=purple,title = "rsi-14")
plot(rsi5, color=blue,title = "rsi-5")

```
