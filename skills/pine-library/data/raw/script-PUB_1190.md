---
id: PUB;1190
title: Ultimate Oscillator Divergence Detector v0.1
author: blackdog6621
type: indicator
tags: []
boosts: 1219
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1190
---

# Description
Ultimate Oscillator Divergence Detector v0.1

# Source Code
```pine
study("blackdog6621s Ultimate Oscillator Divergence Detector v0.1", shorttitle="UO Div Detector v0.1", overlay=true)

spacing = input(7)
length7 = input(7, minval=1), length14 = input(14, minval=1), length28 = input(28, minval=1)

average(bp, tr_, length) => sum(bp, length) / sum(tr_, length)
high_ = max(high, close[1])
low_ = min(low, close[1])
bp = close - low_
tr_ = high_ - low_
avg7 = average(bp, tr_, length7)
avg14 = average(bp, tr_, length14)
avg28 = average(bp, tr_, length28)
uo = 100 * (4*avg7 + 2*avg14 + avg28)/7

lowest_in_segment(s_close, s_osc, length) =>
    min_bar = lowestbars(s_close, length)
    min_val = lowest(s_close, length)
    next_s_close = offset(s_close, length)
    osc_val = lowest(s_osc, length)
    next_s_osc = offset(s_osc, length)
    [min_bar, min_val, osc_val, next_s_close, next_s_osc]

s_close = close
s_osc = uo
[low_bar_1, low_val_1, low_osc_1, low_s_close_1, low_s_osc_1] = lowest_in_segment(s_close, s_osc, spacing)
[low_bar_2, low_val_2, low_osc_2, low_s_close_2, low_s_osc_2] = lowest_in_segment(low_s_close_1, low_s_osc_1, spacing)
[low_bar_3, low_val_3, low_osc_3, low_s_close_3, low_s_osc_3] = lowest_in_segment(low_s_close_2, low_s_osc_2, spacing)
[low_bar_4, low_val_4, low_osc_4, low_s_close_4, low_s_osc_4] = lowest_in_segment(low_s_close_3, low_s_osc_3, spacing)
[low_bar_5, low_val_5, low_osc_5, low_s_close_5, low_s_osc_5] = lowest_in_segment(low_s_close_4, low_s_osc_4, spacing)
[low_bar_6, low_val_6, low_osc_6, low_s_close_6, low_s_osc_6] = lowest_in_segment(low_s_close_5, low_s_osc_5, spacing)

lowest_padded(series) => lowest(series, spacing * 3)

first_low = 1

second_low_5x() => low_val_5 < low_val_6 ? 5 : 6
second_low_4x() => lowest_padded(low_s_close_2) == low_val_4 ? 4 : second_low_5x()
second_low_34() => lowest_padded(low_s_close_1) == low_val_3 ? 3 : second_low_4x()
second_low_3x() => first_low != 3 ? second_low_34() : second_low_4x()
second_low_23() => lowest_padded(s_close) == low_val_2 ? 2 : second_low_34()
second_low = first_low == 1 ? second_low_23() : second_low_3x()

seg(i, seg_1, seg_2, seg_3, seg_4, seg_5, seg_6) =>
    i == 1 ? seg_1 : (i == 2 ? seg_2 : (i == 3 ? seg_3 : (i == 4 ? seg_4 : (i == 5 ? seg_5 : seg_6))))
first_low_val = seg(first_low, low_val_1, low_val_2, low_val_3, low_val_4, low_val_5, low_val_6)
first_low_bar = (first_low - 1) * spacing +
    seg(first_low, low_bar_1, low_bar_2, low_bar_3, low_bar_4, low_bar_5, low_bar_6)
second_low_val = seg(second_low, low_val_1, low_val_2, low_val_3, low_val_4, low_val_5, low_val_6)
second_low_bar = (second_low - 1) * spacing +
    seg(second_low, low_bar_1, low_bar_2, low_bar_3, low_bar_4, low_bar_5, low_bar_6)

first_osc_val = seg(first_low, low_osc_1, low_osc_2, low_osc_3, low_osc_4, low_osc_5, low_osc_6)
second_osc_val = seg(second_low, low_osc_1, low_osc_2, low_osc_3, low_osc_4, low_osc_5, low_osc_6)

val_lows_direction = sign(first_low_val - second_low_val)
osc_lows_direction = sign(first_osc_val - second_osc_val)

n_bull_diff = val_lows_direction < 0 and osc_lows_direction >= 0
bgcolor(n_bull_diff ? lime : na, transp=85) //, offset=-8)

```
