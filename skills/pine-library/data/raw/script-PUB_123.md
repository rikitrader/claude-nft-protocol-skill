---
id: PUB;123
title: Bollinger Fanboy
author: sh3rmfx
type: indicator
tags: []
boosts: 278
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_123
---

# Description
Bollinger Fanboy

# Source Code
```pine
study(title="Bollinger Fanboy", shorttitle="Bollinger Fanboy", overlay=true)

bf_middle = sma(close, 20)
bf_top = bf_middle + (stdev(close, 20) * 2)
bf_bottom = bf_middle - (stdev(close, 20) * 2)

bf_short_entry = low
bf_short_stop = high
bf_short_exit = low - ((high-low) * 1.5)

bf_long_entry = high
bf_long_stop = low
bf_long_exit = high + ((high-low) * 1.5)

bf_long = close < bf_middle ? (close > bf_bottom ? true : false) : false
bf_short = close > bf_middle ? (close < bf_top ? true : false) : false

bf_lowest = low == lowest(10) ? ( low < bf_bottom ? true : false ) : false
bf_highest = high == highest(10) ? ( high > bf_top ? true : false ) : false

bf_go_long = bf_long ? ( bf_lowest ? ( bf_long_exit < bf_middle ? true : false ) : false ) : false
bf_go_short = bf_short ? ( bf_highest ? ( bf_short_exit > bf_middle ? true : false ) : false ) : false

bf_enter = bf_go_long ? bf_long_entry : ( bf_go_short ? bf_short_entry : bf_enter[1] )
bf_exit = bf_go_long ? bf_long_exit : ( bf_go_short ? bf_short_exit : bf_exit[1] )
bf_stop = bf_go_long ? bf_long_stop : ( bf_go_short ? bf_short_stop : bf_stop[1] )

plot(bf_enter == bf_enter[10] ? na : bf_enter, title="Entry", color=orange, style=circles)
plot(bf_enter == bf_enter[10] ? na : bf_exit, title="Exit", color=green, style=circles)
plot(bf_enter == bf_enter[10] ? na : bf_stop, title="Stop", color=red, style=circles)
```
