---
id: PUB;1762
title: [NM]Improved Linear Regression Bull and Bear Power v02
author: Profit_Through_Patience
type: indicator
tags: []
boosts: 2688
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1762
---

# Description
[NM]Improved Linear Regression Bull and Bear Power v02

# Source Code
```pine
//@version=2
// this code uses the Linear Regression Bull and Bear Power indicator created by RicardoSantos
// and adds a signal line 
// Use : if signal line is changes color, you have your signal, green = buy, red = sell
// Advice : best used with a zero lag indicator like ZeroLagEMA_LB from LazyBear
// if price is above ZLEMA and signal = green => buy, price below ZLEMA and signal = red => sell
// ***** Changelog compared to v01 ******
// Adapted formula to calculate the signal in case there is no information for either bear or bull
// Added the possibility to smoothen the signal (this is done by a simple SMA)
// Added zero line
study(title='[RS][NM]Improved Linear Regression Bull and Bear Power v02', shorttitle='BBP_NM_v02', overlay=false)
window = input(title='Lookback Window:', type=integer, defval=10)
smooth = input(title='Smooth ?', type=bool, defval=true)
smap = input(title='Smooth factor', type=integer, defval=5, minval=2, maxval=10)
sigma = input(title='Sigma', type=integer, defval=6)


f_exp_lr(_height, _length)=>
    _ret = _height + (_height/_length)

h_value = highest(close, window)
l_value = lowest(close, window)

h_bar = n-highestbars(close, window)
l_bar = n-lowestbars(close, window)

bear = 0-(f_exp_lr(h_value-close, n-h_bar) > 0 ? f_exp_lr(h_value-close, n-h_bar) : 0)
bull = 0+(f_exp_lr(close-l_value, n-l_bar) > 0 ? f_exp_lr(close-l_value, n-l_bar) : 0)
direction = smooth ? alma(bull + bear, smap, 0.9, sigma) : bull*3 + bear*3
dcolor = smooth ? direction[0] > direction[1] ? green : direction[0] < direction[1] ? red : yellow : direction > bull ? green : direction < bear ? red : yellow

plot(title='Bear', series=bear, style=columns, color=maroon, transp=92)
plot(title='Bull', series=bull, style=columns, color=green, transp=92)
plot(title='Direction', series=direction, style=line, linewidth=3, color= dcolor)
plot(0,title='zero line', color=black, linewidth=2)


```
