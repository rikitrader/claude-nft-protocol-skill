---
id: PUB;130
title: Bollinger Fanboy v4.0
author: sh3rmfx
type: indicator
tags: []
boosts: 582
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_130
---

# Description
Bollinger Fanboy v4.0

# Source Code
```pine
study(title="Bollinger Fanboy", shorttitle="Bollinger Fanboy", overlay=true)
bf_spread = input(title="Spread", type=float, defval=0.0000)
bf_period = 20
bf_stddev = 2
bf_profit = input(title="Profit Ratio", type=float, defval=1.50)
bf_rsi = 30
bf_rsi_inner = 10

bf_middle = sma(close, bf_period)
bf_top = bf_middle + (stdev(close, bf_period) * bf_stddev)
bf_bottom = bf_middle - (stdev(close, bf_period) * bf_stddev)

bf_height = ((high + bf_spread) - (low - bf_spread)) * bf_profit

bf_short_entry = low - bf_spread
bf_short_stop = high + bf_spread
bf_short_exit = bf_short_entry - bf_height

bf_long_entry = high + bf_spread
bf_long_stop = low - bf_spread
bf_long_exit = bf_long_entry + bf_height

bf_long = close < bf_middle ? (close > bf_bottom ? true : false) : false
bf_short = close > bf_middle ? (close < bf_top ? true : false) : false

bf_lowest = low == lowest(bf_period / 2) ? ( low < bf_bottom ? true : false ) : false
bf_highest = high == highest(bf_period / 2) ? ( high > bf_top ? true : false ) : false

bf_rsi_long = rsi(close, 20) > (50 + bf_rsi_inner) ? (rsi(close, 20) < (50 + bf_rsi) ? true : false) : false
bf_rsi_short = rsi(close, 20) < (50 - bf_rsi_inner) ? (rsi(close, 20) > (50 - bf_rsi) ? true : false) : false

bf_go_long = bf_long ? ( bf_lowest ? ( bf_long_exit < (bf_middle - bf_spread) ? (bf_rsi_short ? true : false) : false ) : false ) : false
bf_go_short = bf_short ? ( bf_highest ? ( bf_short_exit > (bf_middle + bf_spread) ? (bf_rsi_long ? true : false) : false ) : false ) : false

bf_enter = bf_go_long ? bf_long_entry : ( bf_go_short ? bf_short_entry : bf_enter[1] )
bf_exit = bf_go_long ? bf_long_exit : ( bf_go_short ? bf_short_exit : bf_exit[1] )
bf_stop = bf_go_long ? bf_long_stop : ( bf_go_short ? bf_short_stop : bf_stop[1] )

plot(bf_enter == bf_enter[bf_period] ? na : bf_enter, title="Entry", color=orange, style=circles, linewidth=2)
plot(bf_enter == bf_enter[bf_period] ? na : bf_exit, title="Exit", color=green, style=circles, linewidth=2)
plot(bf_enter == bf_enter[bf_period] ? na : bf_stop, title="Stop", color=red, style=circles, linewidth=2)
```
