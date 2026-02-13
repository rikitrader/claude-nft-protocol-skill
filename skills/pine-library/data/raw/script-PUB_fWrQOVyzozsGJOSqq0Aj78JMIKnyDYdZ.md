---
id: PUB;fWrQOVyzozsGJOSqq0Aj78JMIKnyDYdZ
title: [RS]Swing Charts V0 Trend Counter V0
author: RicardoSantos
type: indicator
tags: []
boosts: 2223
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_fWrQOVyzozsGJOSqq0Aj78JMIKnyDYdZ
---

# Description
[RS]Swing Charts V0 Trend Counter V0

# Source Code
```pine
//@version=2
study(title='[RS]Swing Charts V0 Trend Counter V0', shorttitle='SCTC', overlay=true)
SHOW_BARCOLOR = input(title='Overwrite Bar Colors?', type=bool, defval=false)
SHOW_ZIGZAG_LVL0 = input(title='Display ZigZag Level 0?', type=bool, defval=false)
SHOW_SWINGCHART_LVL0 = input(title='Display Swing Chart Stops Level 0?', type=bool, defval=false)
SHOW_SWINGSIGNAL_LVL0 = input(title='Display Swing Signals Level 0?', type=bool, defval=false)

f_up_bar(_previous_high, _current_high, _previous_low, _current_low)=>
    _return = _previous_high < _current_high and _previous_low < _current_low

f_down_bar(_previous_high, _current_high, _previous_low, _current_low)=>
    _return = _previous_high > _current_high and _previous_low > _current_low

f_inside_bar(_previous_high, _current_high, _previous_low, _current_low)=>
    _return = _previous_high >= _current_high and _previous_low <= _current_low

f_outside_bar(_previous_high, _current_high, _previous_low, _current_low)=>
    _return = _previous_high <= _current_high and _previous_low >= _current_low

//--
f_swing_high(_previous_high, _current_high, _previous_low, _current_low)=>
    _condition_00 = f_up_bar(_previous_high[1], _current_high[1], _previous_low[1], _current_low[1]) and f_down_bar(_previous_high, _current_high, _previous_low, _current_low)
    _condition_01 = f_outside_bar(_previous_high[1], _current_high[1], _previous_low[1], _current_low[1]) and f_down_bar(_previous_high, _current_high, _previous_low, _current_low)
    _condition_02 = f_inside_bar(_previous_high[1], _current_high[1], _previous_low[1], _current_low[1]) and f_down_bar(_previous_high, _current_high, _previous_low, _current_low)
    _condition_03 = f_up_bar(_previous_high[1], _current_high[1], _previous_low[1], _current_low[1]) and f_inside_bar(_previous_high, _current_high, _previous_low, _current_low) and close[0] < hl2[1]
    _condition_04 = f_outside_bar(_previous_high, _current_high, _previous_low, _current_low) and close < hl2
    _condition_05 = false
    _return = _condition_00 or _condition_01 or _condition_02 or _condition_03 or _condition_04 or _condition_05

f_swing_low(_previous_high, _current_high, _previous_low, _current_low)=>
    _condition_00 = f_down_bar(_previous_high[1], _current_high[1], _previous_low[1], _current_low[1])      and f_up_bar(_previous_high, _current_high, _previous_low, _current_low)
    _condition_01 = f_outside_bar(_previous_high[1], _current_high[1], _previous_low[1], _current_low[1])   and f_up_bar(_previous_high, _current_high, _previous_low, _current_low)
    _condition_02 = f_inside_bar(_previous_high[1], _current_high[1], _previous_low[1], _current_low[1])    and f_up_bar(_previous_high, _current_high, _previous_low, _current_low)
    _condition_03 = f_down_bar(_previous_high[1], _current_high[1], _previous_low[1], _current_low[1])      and f_inside_bar(_previous_high, _current_high, _previous_low, _current_low) and close[0] > hl2[1]
    _condition_04 = f_outside_bar(_previous_high, _current_high, _previous_low, _current_low)               and close > hl2
    _condition_05 = false
    _return = _condition_00 or _condition_01 or _condition_02 or _condition_03 or _condition_04 or _condition_05
//--
f_swingchart(_swings_high, _swings_low)=>
    _trend = na(_trend[1]) ? 1 : _trend[1] > 0 and _swings_low ? -1 : _trend[1] < 0 and _swings_high ? 1 : _trend[1]
    _return = na(_return[1]) ? 0 : change(_trend) > 0 ? nz(_swings_high, high[1]) : change(_trend) < 0 ? nz(_swings_low, low[1]) : _return[1]

swings_high_lvl0 = f_swing_high(high[1], high, low[1], low) ? highest(3) : na
swings_low_lvl0 = f_swing_low(high[1], high, low[1], low) ? lowest(3) : na

swing_chart_lvl0 = f_swingchart(swings_high_lvl0, swings_low_lvl0)
zigzag_lvl0 = change(swing_chart_lvl0) != 0 ? swing_chart_lvl0 : na
zigzag_lvl0_trend = na(zigzag_lvl0_trend[1]) ? 1 : change(swing_chart_lvl0) > 0 ? 1 : change(swing_chart_lvl0) < 0 ? -1 : zigzag_lvl0_trend[1]

plotshape(title='Swing High 0'  , series=not SHOW_SWINGSIGNAL_LVL0 ? na : swings_high_lvl0  , style=shape.triangledown  , location=location.abovebar, color=red, transp=0, offset=-1)
plotshape(title='Swing Low 0'   , series=not SHOW_SWINGSIGNAL_LVL0 ? na : swings_low_lvl0   , style=shape.triangleup    , location=location.belowbar, color=lime, transp=0, offset=-1)
plot(title='Swing Chart 0'      , series=not SHOW_SWINGCHART_LVL0 ? na : swing_chart_lvl0   , color=change(swing_chart_lvl0) != 0 ? na : black  , transp=0, offset=-1)
plot(title='ZigZag 0'           , series=not SHOW_ZIGZAG_LVL0 ? na : zigzag_lvl0            , color=zigzag_lvl0_trend > 0 ? lime : red, transp=0, linewidth=1, offset=-1)

barcolor(title='Up Bar'         , color=not SHOW_BARCOLOR ? na : f_up_bar(high[1], high, low[1], low) ? lime : na        )
barcolor(title='Down Bar'       , color=not SHOW_BARCOLOR ? na : f_down_bar(high[1], high, low[1], low) ? red : na       )
barcolor(title='Inside Bar'     , color=not SHOW_BARCOLOR ? na : f_inside_bar(high[1], high, low[1], low) ? blue : na    )
barcolor(title='Outside Bar'    , color=not SHOW_BARCOLOR ? na : f_outside_bar(high[1], high, low[1], low) ? aqua : na   )

//  ||---   Trend Counter:

is_swing_high = zigzag_lvl0 and zigzag_lvl0 >= highest(3) ? true : false
is_swing_low = zigzag_lvl0 and zigzag_lvl0 <= lowest(3) ? true : false

d = valuewhen(zigzag_lvl0, zigzag_lvl0, 0)
c = valuewhen(zigzag_lvl0, zigzag_lvl0, 1)
b = valuewhen(zigzag_lvl0, zigzag_lvl0, 2)

// plot(d, color=blue, offset=-1)
// plot(b, color=red, offset=-1)

count_up = na(count_up[1]) ? 0 : is_swing_high and d > b ? count_up[1] + 1 : is_swing_low and d > b ? count_up[1] + 1 : is_swing_high and d <= b ? 0 : is_swing_low and d <= b ? 0 : count_up[1]
count_down = na(count_down[1]) ? 0 : is_swing_low and d < b ? count_down[1] + 1 : is_swing_high and d < b ? count_down[1] + 1 : is_swing_low and d >= b ? 0 : is_swing_high and d >= b ? 0 : count_down[1]

plotchar(series=is_swing_high and count_up == 1 ? true : false, title='', char='1', location=location.abovebar, color=green, transp=0, offset=-1)
plotchar(series=is_swing_high and count_up == 2 ? true : false, title='', char='2', location=location.abovebar, color=green, transp=0, offset=-1)
plotchar(series=is_swing_high and count_up == 3 ? true : false, title='', char='3', location=location.abovebar, color=green, transp=0, offset=-1)
plotchar(series=is_swing_high and count_up == 4 ? true : false, title='', char='4', location=location.abovebar, color=green, transp=0, offset=-1)
plotchar(series=is_swing_high and count_up == 5 ? true : false, title='', char='5', location=location.abovebar, color=green, transp=0, offset=-1)

plotchar(series=is_swing_low and count_up == 1 ? true : false, title='', char='1', location=location.belowbar, color=green, transp=0, offset=-1)
plotchar(series=is_swing_low and count_up == 2 ? true : false, title='', char='2', location=location.belowbar, color=green, transp=0, offset=-1)
plotchar(series=is_swing_low and count_up == 3 ? true : false, title='', char='3', location=location.belowbar, color=green, transp=0, offset=-1)
plotchar(series=is_swing_low and count_up == 4 ? true : false, title='', char='4', location=location.belowbar, color=green, transp=0, offset=-1)
plotchar(series=is_swing_low and count_up == 5 ? true : false, title='', char='5', location=location.belowbar, color=green, transp=0, offset=-1)

plotchar(series=is_swing_high and count_down == 1 ? true : false, title='', char='1', location=location.abovebar, color=maroon, transp=0, offset=-1)
plotchar(series=is_swing_high and count_down == 2 ? true : false, title='', char='2', location=location.abovebar, color=maroon, transp=0, offset=-1)
plotchar(series=is_swing_high and count_down == 3 ? true : false, title='', char='3', location=location.abovebar, color=maroon, transp=0, offset=-1)
plotchar(series=is_swing_high and count_down == 4 ? true : false, title='', char='4', location=location.abovebar, color=maroon, transp=0, offset=-1)
plotchar(series=is_swing_high and count_down == 5 ? true : false, title='', char='5', location=location.abovebar, color=maroon, transp=0, offset=-1)

plotchar(series=is_swing_low and count_down == 1 ? true : false, title='', char='1', location=location.belowbar, color=maroon, transp=0, offset=-1)
plotchar(series=is_swing_low and count_down == 2 ? true : false, title='', char='2', location=location.belowbar, color=maroon, transp=0, offset=-1)
plotchar(series=is_swing_low and count_down == 3 ? true : false, title='', char='3', location=location.belowbar, color=maroon, transp=0, offset=-1)
plotchar(series=is_swing_low and count_down == 4 ? true : false, title='', char='4', location=location.belowbar, color=maroon, transp=0, offset=-1)
plotchar(series=is_swing_low and count_down == 5 ? true : false, title='', char='5', location=location.belowbar, color=maroon, transp=0, offset=-1)

```
