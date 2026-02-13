---
id: PUB;3082
title: [RS]Renko Auto Cloner V0
author: RicardoSantos
type: indicator
tags: []
boosts: 605
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_3082
---

# Description
[RS]Renko Auto Cloner V0

# Source Code
```pine
//@version=2
study(title='[RS]Renko Auto Cloner V0', shorttitle='lv', overlay=true)
use_current_timeframe = input(true)
alternative_timeframe = input('5')
renko_data_source = input('close')
renko_mode = input('ATR')
renko_mode_value = input(defval=100, type=float)
t = renko(tickerid, renko_data_source, renko_mode, renko_mode_value)

ro = security(t, use_current_timeframe ? period : alternative_timeframe, open)
rc = security(t, use_current_timeframe ? period : alternative_timeframe, close)

is_new_direction = change(rc-ro) != 0
sr = is_new_direction ? ro : sr[1]

n01 = plot(series=is_new_direction ? na : sr-(rc-ro), title='-1', color=red, style=linebr, transp=0)
p00 = plot(series=is_new_direction ? na : sr, title='0', color=black, style=linebr, transp=0)
p01 = plot(series=is_new_direction ? na : sr+(rc-ro) * 1, title='1', color=blue, style=linebr, transp=0)
p02 = plot(series=is_new_direction ? na : sr+(rc-ro) * 2, title='2', color=black, style=linebr, transp=0)
p03 = plot(series=is_new_direction ? na : sr+(rc-ro) * 3, title='3', color=black, style=linebr, transp=0)
p04 = plot(series=is_new_direction ? na : sr+(rc-ro) * 4, title='4', color=black, style=linebr, transp=0)
p05 = plot(series=is_new_direction ? na : sr+(rc-ro) * 5, title='5', color=black, style=linebr, transp=0)
p06 = plot(series=is_new_direction ? na : sr+(rc-ro) * 6, title='6', color=black, style=linebr, transp=0)
p07 = plot(series=is_new_direction ? na : sr+(rc-ro) * 7, title='7', color=black, style=linebr, transp=0)
p08 = plot(series=is_new_direction ? na : sr+(rc-ro) * 8, title='8', color=black, style=linebr, transp=0)
p09 = plot(series=is_new_direction ? na : sr+(rc-ro) * 9, title='9', color=black, style=linebr, transp=0)
p10 = plot(series=is_new_direction ? na : sr+(rc-ro) * 10, title='10', color=black, style=linebr, transp=0)

fill(plot1=p00, plot2=p01, color=blue, transp=90, title='BG01')

```
