---
id: PUB;1686
title: [RS]RSI Divergence V5
author: SpreadEagle71
type: indicator
tags: []
boosts: 2132
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1686
---

# Description
[RS]RSI Divergence V5

# Source Code
```pine
study(title='[RS]RSI Divergence V5')
length = input(5)

f_top_fractal(_src)=>_src[4] < _src[2] and _src[3] < _src[2] and _src[2] > _src[1] and _src[2] > _src[0]
f_bot_fractal(_src)=>_src[4] > _src[2] and _src[3] > _src[2] and _src[2] < _src[1] and _src[2] < _src[0]
f_fractalize(_src)=>f_top_fractal(_src) ? 1 : f_bot_fractal(_src) ? -1 : 0

rsi_high = rsi(high, length)
rsi_low = rsi(low, length)
fractal_top_rsi = f_fractalize(rsi_high) > 0 ? rsi_high[2] : na
fractal_bot_rsi = f_fractalize(rsi_low) < 0 ? rsi_low[2] : na

rsi_high_prev = valuewhen(fractal_top_rsi, rsi_high[2], 1) 
rsi_high_price = valuewhen(fractal_top_rsi, high[2], 1)
rsi_low_prev = valuewhen(fractal_bot_rsi, rsi_low[2], 1) 
rsi_low_price = valuewhen(fractal_bot_rsi, low[2], 1)

regular_bearish_div = fractal_top_rsi and high[2] > rsi_high_price and rsi_high[2] < rsi_high_prev
hidden_bearish_div = fractal_top_rsi and high[2] < rsi_high_price and rsi_high[2] > rsi_high_prev
regular_bullish_div = fractal_bot_rsi and low[2] < rsi_low_price and rsi_low[2] > rsi_low_prev
hidden_bullish_div = fractal_bot_rsi and low[2] > rsi_low_price and rsi_low[2] < rsi_low_prev

plot(title='RSI High', series=rsi_high, color=gray)
plot(title='RSI Low', series=rsi_low, color=gray)
plot(title='RSI H F', series=fractal_top_rsi, color=black, offset=-2)
plot(title='RSI L F', series=fractal_bot_rsi, color=black, offset=-2)
plot(title='RSI H D', series=fractal_top_rsi, style=circles, color=regular_bearish_div or hidden_bearish_div ? maroon : gray, linewidth=3, offset=-2)
plot(title='RSI L D', series=fractal_bot_rsi, style=circles, color=regular_bullish_div or hidden_bullish_div ? green : gray, linewidth=3, offset=-2)

plotshape(title='+RBD', series=regular_bearish_div ? rsi_high[2] : na, text='Regular', style=shape.labeldown, location=location.absolute, color=maroon, textcolor=white, offset=-2)
plotshape(title='+HBD', series=hidden_bearish_div ? rsi_high[2] : na, text='hidden', style=shape.labeldown, location=location.absolute, color=maroon, textcolor=white, offset=-2)
plotshape(title='-RBD', series=regular_bullish_div ? rsi_low[2] : na, text='Regular', style=shape.labelup, location=location.absolute, color=green, textcolor=white, offset=-2)
plotshape(title='-HBD', series=hidden_bullish_div ? rsi_low[2] : na, text='hidden', style=shape.labelup, location=location.absolute, color=green, textcolor=white, offset=-2)
```
