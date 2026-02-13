---
id: PUB;2702
title: 3 Exponential Moving Averages
author: TradeTitan
type: indicator
tags: []
boosts: 645
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2702
---

# Description
3 Exponential Moving Averages

# Source Code
```pine
study(title="3 Exponential Moving Averages", shorttitle="3EMA", overlay=true)
len1 = input(20, minval=1, title="Short Length")
src1 = input(close, title="Source One")
out1 = ema(src1, len1)
plot(out1, title="Short EMA", color=blue)
len2 = input(50, minval=1, title="Intermediate Length")
src2 = input(close, title="Source Two")
out2 = ema(src2, len2)
plot(out2, title="Intermediate EMA", color=orange)
len3 = input(100, minval=1, title="Long Length")
src3 = input(close, title="Source Three")
out3 = ema(src3, len3)
plot(out3, title="Long EMA", color=green)
```
