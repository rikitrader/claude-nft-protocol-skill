---
id: PUB;2188
title: Average True Range Overlay - Band
author: gb50k
type: indicator
tags: []
boosts: 66
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2188
---

# Description
Average True Range Overlay - Band

# Source Code
```pine
study(title="Average True Range Overlay", shorttitle="ATRO", overlay=true)
length = input(14, minval=1)
plot(hl2+(rma(tr(true), length))/2, color=blue, linewidth=2)
plot(hl2-(rma(tr(true), length))/2, color=blue, linewidth=2)
```
