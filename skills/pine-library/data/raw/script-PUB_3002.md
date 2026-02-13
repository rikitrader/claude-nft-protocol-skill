---
id: PUB;3002
title: [RS]Volatility Explosive Measure V0
author: RicardoSantos
type: indicator
tags: []
boosts: 274
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_3002
---

# Description
[RS]Volatility Explosive Measure V0

# Source Code
```pine
//@version=2
study(title='[RS]Volatility Explosive Measure V0')
f_bullish_sequence()=>
    _output = 0
    _range = close - open
    _doji = _range == 0
    _up_bar = _range > 0 or _doji and _range[1] > 0
    _counter = barssince(not _up_bar)
    if (_up_bar)
        for _i = 0 to max(0, _counter - 1)
            _output := _output + _range[_i]
    _output

f_bearish_sequence()=>
    _output = 0
    _range = close - open
    _doji = _range == 0
    _up_bar = _range < 0 or _doji and _range[1] < 0
    _counter = barssince(not _up_bar)
    if (_up_bar)
        for _i = 0 to max(0, _counter - 1)
            _output := _output + _range[_i]
    _output

bull_seq = f_bullish_sequence()
bear_seq = f_bearish_sequence()

length = input(10)
bull_ma = ema(bull_seq, length)
bear_ma = ema(bear_seq, length)
width = bull_ma - bear_ma

plot(width, color=color(black, 0), style=area)
// plot(bull_seq, color=color(lime, 0), style=columns)
// plot(bear_seq, color=color(red, 0), style=columns)
// plot(bull_ma, color=color(purple, 25), style=area)
// plot(bear_ma, color=color(purple, 25), style=area)

```
