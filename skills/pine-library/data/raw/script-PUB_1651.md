---
id: PUB;1651
title: [RS]Accumulation and Distribution Divergence V0
author: RicardoSantos
type: indicator
tags: []
boosts: 1111
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1651
---

# Description
[RS]Accumulation and Distribution Divergence V0

# Source Code
```pine
study(title='[RS]Accumulation and Distribution Divergence V0')

smooth = input(1)

f_top_fractal(_src)=>_src[4] < _src[2] and _src[3] < _src[2] and _src[2] > _src[1] and _src[2] > _src[0]
f_bot_fractal(_src)=>_src[4] > _src[2] and _src[3] > _src[2] and _src[2] < _src[1] and _src[2] < _src[0]
f_fractalize(_src)=>f_top_fractal(_src) ? 1 : f_bot_fractal(_src) ? -1 : 0

hist = sma(cum(close==high and close==low or high==low ? 0 : ((2*close-low-high)/(high-low))*volume), smooth)

fractal_top = f_fractalize(hist) > 0 ? hist[2] : na
fractal_bot = f_fractalize(hist) < 0 ? hist[2] : na

high_prev = valuewhen(fractal_top, hist[2], 1) 
high_price = valuewhen(fractal_top, high[2], 1)
low_prev = valuewhen(fractal_bot, hist[2], 1) 
low_price = valuewhen(fractal_bot, low[2], 1)

regular_bearish_div = fractal_top and high[2] > high_price and hist[2] < high_prev
hidden_bearish_div = fractal_top and high[2] < high_price and hist[2] > high_prev
regular_bullish_div = fractal_bot and low[2] < low_price and hist[2] > low_prev
hidden_bullish_div = fractal_bot and low[2] > low_price and hist[2] < low_prev

plot(title='HIST', series=hist, color=black)
plot(title='H F', series=fractal_top, color=regular_bearish_div or hidden_bearish_div ? black : silver, offset=-2)
plot(title='L F', series=fractal_bot, color=regular_bullish_div or hidden_bullish_div ? black : silver, offset=-2)
plot(title='H D', series=fractal_top, style=circles, color=regular_bearish_div or hidden_bearish_div ? maroon : gray, linewidth=3, offset=-2)
plot(title='L D', series=fractal_bot, style=circles, color=regular_bullish_div or hidden_bullish_div ? green : gray, linewidth=3, offset=-2)

plotshape(title='+RBD', series=regular_bearish_div ? hist[2] : na, text='R', style=shape.labeldown, location=location.absolute, color=maroon, textcolor=white, offset=-2)
plotshape(title='+HBD', series=hidden_bearish_div ? hist[2] : na, text='H', style=shape.labeldown, location=location.absolute, color=maroon, textcolor=white, offset=-2)
plotshape(title='-RBD', series=regular_bullish_div ? hist[2] : na, text='R', style=shape.labelup, location=location.absolute, color=green, textcolor=white, offset=-2)
plotshape(title='-HBD', series=hidden_bullish_div ? hist[2] : na, text='H', style=shape.labelup, location=location.absolute, color=green, textcolor=white, offset=-2)

```
