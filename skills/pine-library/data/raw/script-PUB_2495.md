---
id: PUB;2495
title: Function Simple Moving Average
author: RicardoSantos
type: indicator
tags: []
boosts: 634
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2495
---

# Description
Function Simple Moving Average

# Source Code
```pine
//@version=2
study(title='Function Simple Moving Average', overlay=true)
src = input(close)
length = input(10)

f_sma(_src, _length)=>
    _length_adjusted = _length < 1 ? 1 : _length
    _sum = 0
    for _i = 0 to (_length_adjusted - 1)
        _sum := _sum + _src[_i]
    _return = _sum / _length_adjusted

plot(sma(src, length), color=color(gray, 0), linewidth=5)
plot(f_sma(src, length), color=color(blue, 0), linewidth=1)


```
