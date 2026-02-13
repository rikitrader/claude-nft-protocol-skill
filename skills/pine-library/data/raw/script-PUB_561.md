---
id: PUB;561
title: True Strength Indicator MTF
author: QuantitativeExhaustion
type: indicator
tags: []
boosts: 1861
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_561
---

# Description
True Strength Indicator MTF

# Source Code
```pine
study("True Strength Indicator MTF", shorttitle="TSI MTF")
resCustom = input(title="Timeframe", type=resolution, defval="60" )
long = input(title="Long Length", type=integer, defval=25)
short = input(title="Short Length", type=integer, defval=13)
signal = input(title="Signal Length", type=integer, defval=13)
price = close
double_smooth(src, long, short) =>
    fist_smooth = ema(src, long)
    ema(fist_smooth, short)
pc = change(price)
double_smoothed_pc = double_smooth(pc, long, short)
double_smoothed_abs_pc = double_smooth(abs(pc), long, short)
tsi_value = 100 * (double_smoothed_pc / double_smoothed_abs_pc)
plot(tsi_value, color=black)
plot(ema(tsi_value, signal), color=red)
hline(0, title="Zero")
```
