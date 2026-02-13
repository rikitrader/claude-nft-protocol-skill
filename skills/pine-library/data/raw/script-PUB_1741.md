---
id: PUB;1741
title: [RS][NM]Improved Linear Regression Bull and Bear Power v01
author: Profit_Through_Patience
type: indicator
tags: []
boosts: 2954
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1741
---

# Description
[RS][NM]Improved Linear Regression Bull and Bear Power v01

# Source Code
```pine
//@version=1
// this code uses the Linear Regression Bull and Bear Power indicator created by RicardoSantos
// and adds a signal line 
// Use : if signal line is changes color, you have your signal, green = buy, red = sell
// Advice : best used with a zero lag indicator like ZeroLagEMA_LB from LazyBear
// if price is above ZLEMA and signal = green => buy, price below ZLEMA and signal = red => sell
study(title='[RS][NM]Improved Linear Regression Bull and Bear Power v01', shorttitle='BBP_NM', overlay=false)
window = input(title='Lookback Window:', type=integer, defval=10)

f_exp_lr(_height, _length)=>
    _ret = _height + (_height/_length)

h_value = highest(close, window)
l_value = lowest(close, window)

h_bar = n-highestbars(close, window)
l_bar = n-lowestbars(close, window)

bear = 0-f_exp_lr(h_value-close, n-h_bar)
bull = 0+f_exp_lr(close-l_value, n-l_bar)
direction = bull*2 + bear*2

plot(title='Bear', series=bear, style=columns, color=maroon, transp=90)
plot(title='Bull', series=bull, style=columns, color=green, transp=90)
plot(title='Direction', series=direction, style=line, linewidth=3, color= direction > 0 ? green : red)
```
