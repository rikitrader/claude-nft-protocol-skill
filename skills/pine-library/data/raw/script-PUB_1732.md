---
id: PUB;1732
title: Momentum-RSI-Signal
author: brayrikar
type: indicator
tags: []
boosts: 330
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1732
---

# Description
Momentum-RSI-Signal

# Source Code
```pine
study(title="Momentum-RSI-Sig", shorttitle="MRSI")
len = input(10, minval=1, title="Length")
src = input(close, title="Source")
mom = src - src[len]
mom_prev = src[1] - src[11]
src_rsi = input(close, title="Source"),len_rsi = input(14, minval=1, title="Length")
up = rma(max(change(src_rsi), 0), len_rsi)
down = rma(-min(change(src_rsi), 0), len_rsi)
up_prev = rma(max(change(src_rsi[1]), 0), len_rsi)
down_prev = rma(-min(change(src_rsi[1]), 0), len_rsi)
rsi = down == 0 ? 100 : up == 0 ? 0 : 100 - (100 / (1 + up / down))
rsi_prev = down_prev == 0 ? 100 : up_prev == 0 ? 0 : 100 - (100 / (1 + up_prev / down_prev))
rsi_dir = rsi  - rsi_prev
mom_dir = mom - mom_prev
signal_dir = (rsi_dir > 0 and rsi < 50 and mom_dir >= 3) ? 100 : 0
plot (signal_dir, color=purple)
```
