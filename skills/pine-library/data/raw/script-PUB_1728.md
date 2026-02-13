---
id: PUB;1728
title: [RS]Linear Regression Bull and Bear Power V0
author: RicardoSantos
type: indicator
tags: []
boosts: 467
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1728
---

# Description
[RS]Linear Regression Bull and Bear Power V0

# Source Code
```pine
//@version=2
study(title='[RS]Linear Regression Bull and Bear Power V0', shorttitle='BBP', overlay=false)
window = input(title='Lookback Window:', type=integer, defval=10)

f_exp_lr(_height, _length)=>
    _ret = _height + (_height/_length)

h_value = highest(close, window)
l_value = lowest(close, window)

h_bar = n-highestbars(close, window)
l_bar = n-lowestbars(close, window)

bear = 0-f_exp_lr(h_value-close, n-h_bar)
bull = 0+f_exp_lr(close-l_value, n-l_bar)

plot(title='Bear', series=bear, style=columns, color=maroon)
plot(title='Bull', series=bull, style=columns, color=green)

```
