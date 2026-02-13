---
id: PUB;152
title: Average True Range %
author: timwest
type: indicator
tags: []
boosts: 1653
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_152
---

# Description
Average True Range %

# Source Code
```pine
study(title="Average True Range %", shorttitle="ATR%", overlay=false)
length = input(14, minval=1)
plot(sma(tr*100/close[1], length), color=red)
```
