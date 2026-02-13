---
id: PUB;1719
title: Candles Pattens (v. 1.14)
author: pilotgsms
type: indicator
tags: []
boosts: 894
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1719
---

# Description
Candles Pattens (v. 1.14)

# Source Code
```pine
study(title="Candles Pattens", overlay=true)
// version: 1.14

delta = close - open
gap = open - close[1]
is_up = delta >= 0
high_len = is_up ? high - close : high - open
low_len = is_up ? open - low : close - low
mod_delta = delta<0 ? -delta:delta
avg_mod = (mod_delta + mod_delta[1] + mod_delta[2] + mod_delta[3] + mod_delta[4] + mod_delta[5] + mod_delta[6] + mod_delta[7] + mod_delta[8] + mod_delta[9])/10

// ENGULF
is_bearish_engulf = -delta > delta[1]*2 and delta[1] > 0 and delta < 0 and delta[2] > 0
is_bullish_engulf = delta > -delta[1]*2 and delta[1] < 0 and delta > 0 and delta[2] < 0
plotshape(is_bearish_engulf, style=shape.triangledown, location=location.abovebar, color=red, title='bearish_englf')
plotshape(is_bearish_engulf, style=shape.triangledown, location=location.abovebar, color=red, title='bearish_englf')
plotshape(is_bullish_engulf, style=shape.triangleup, location=location.belowbar, color=green, title='bullish_englf')

// DOJI
is_doji_up = delta*10 < mod_delta and (high-low) > mod_delta*10 and delta[1] < 0
is_doji_down = delta*10 < mod_delta and (high-low) > mod_delta*10 and delta[1] > 0
plotshape(is_doji_down, style=shape.triangledown, location=location.abovebar, color=red, title='doji_down')
plotshape(is_doji_down, style=shape.triangledown, location=location.abovebar, color=red, title='doji_down')
plotshape(is_doji_up, style=shape.triangleup, location=location.belowbar, color=green, title='doji_up')

// DOJI DRAGONFLY
is_doji_dr_up = delta*10 < mod_delta and low_len*10 < mod_delta and high_len > mod_delta*5 and delta[1] < 0
is_doji_dr_down = delta*10 < mod_delta and high_len*10 < mod_delta and low_len > mod_delta*5 and delta[1] > 0
plotshape(is_doji_dr_down, style=shape.triangledown, location=location.abovebar, color=red, title='doji_dr_down')
plotshape(is_doji_dr_down, style=shape.triangledown, location=location.abovebar, color=red, title='doji_dr_down')
plotshape(is_doji_dr_up, style=shape.triangleup, location=location.belowbar, color=green, title='doji_dr_up')

// 3 SAME TICK
//same_up = delta > mod_delta*2 and delta[1] > mod_delta[1]*2 and delta[2] > mod_delta[2]*2 and is_up 
//same_down = delta*2 < mod_delta and (high-low) > mod_delta*10 and delta[1] > 0
//plotshape(same_down, style=shape.triangledown, location=location.abovebar, color=red, title='3_same_down')
//plotshape(same_down, style=shape.triangledown, location=location.abovebar, color=red, title='3_same_down')
//plotshape(same_up, style=shape.triangleup, location=location.belowbar, color=green, title='3_same_up', offset=2)
//plotshape(same_up, style=shape.triangleup, location=location.belowbar, color=green, title='3_same_up')
//plotshape(same_up, style=shape.triangleup, location=location.belowbar, color=green, title='3_same_up', offset=1)
```
