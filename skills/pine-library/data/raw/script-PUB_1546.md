---
id: PUB;1546
title: Multi Time Frame Exponential Moving Average
author: Jurij
type: indicator
tags: []
boosts: 2978
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1546
---

# Description
Multi Time Frame Exponential Moving Average

# Source Code
```pine
//author Jurij 2015
//default moving average period is 4H because '4h' is missing in the resolution drop down list
study("Multi Time Frame Exponential Moving Average", "MTF EMA", overlay=true)
ma_len = input(title="Length", type=integer, defval=100)
src = input(title="Source", type=source, defval=close)
ma_offset = input(title="Offset", type=integer, defval=0)
res = input(title="Resolution", type=resolution, defval="240")
htf_ma = ema(src, ma_len)
out = security(tickerid, res, htf_ma)
plot(out, color=red, offset=ma_offset)
```
