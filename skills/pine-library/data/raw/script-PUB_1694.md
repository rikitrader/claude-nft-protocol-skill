---
id: PUB;1694
title: [RS]MTF Fibonacci Cycles V0
author: RicardoSantos
type: indicator
tags: []
boosts: 3417
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1694
---

# Description
[RS]MTF Fibonacci Cycles V0

# Source Code
```pine
study(title='[RS]MTF Fibonacci Cycles V0', shorttitle='Fib', overlay=true)
tf = input(title='Timeframe:', type=string, defval='M', confirm=false)
SHOW_ZIGZGAG = input(title='Show ZigZag?', type=bool, defval=false)
f_zigzag(_method, _src, _tf) =>
    _isUp = _src > _src[1]
    _isDown = _src < _src[1]
    _direction = _isUp[1] and _isDown ? -1 : _isDown[1] and _isUp ? 1 : na
    _zigzag = _isUp[1] and _isDown ? highest(2) : _isDown[1] and _isUp ? lowest(2) : na
    _m_choice = _method == 0 ? _direction : _zigzag
    _sec = security(tickerid, _tf, _m_choice)
    _return = _method == 0 ? fixnan(_sec) : change(time(_tf)) != 0 ? _sec : na

zigzag = f_zigzag(1, close, tf)

x = valuewhen(zigzag, zigzag, 1)
z = valuewhen(zigzag, zigzag, 0)
range = x-z

fib0000 = z
fib0236 = z+range*0.236
fib0382 = z+range*0.382
fib0500 = z+range*0.500
fib0618 = z+range*0.618
fib0764 = z+range*0.764
fib1000 = x
fib1272 = z+range*1.272
fib1414 = z+range*1.414
fib1618 = z+range*1.618
fib2000 = z+range*2.000
fib2272 = z+range*2.272
fib2414 = z+range*2.414
fib2618 = z+range*2.618
fib3000 = z+range*3.000
fib3272 = z+range*3.272
fib3414 = z+range*3.414
fib3618 = z+range*3.618
fib4000 = z+range*4.000
fib4236 = z+range*4.236
fib4272 = z+range*4.272
fib4414 = z+range*4.414
fib4618 = z+range*4.618
fib4764 = z+range*4.764

direction = x > z ? 1 : x < z ? -1 : direction[1]
plot(title='ZigZag', series=not SHOW_ZIGZGAG ? na : zigzag, color=black)
plot(title='0.000', series=change(fib0000)!=0?na:fib0000, style=linebr, color=direction>0?green:maroon, linewidth=4)
plot(title='0.236', series=change(fib0236)!=0?na:fib0236, style=linebr, color=red)
plot(title='0.382', series=change(fib0382)!=0?na:fib0382, style=linebr, color=olive)
plot(title='0.500', series=change(fib0500)!=0?na:fib0500, style=linebr, color=lime)
plot(title='0.618', series=change(fib0618)!=0?na:fib0618, style=linebr, color=teal)
plot(title='0.764', series=change(fib0764)!=0?na:fib0764, style=linebr, color=blue)
plot(title='1.000', series=change(fib1000)!=0?na:fib1000, style=linebr, color=black, linewidth=2)
plot(title='1.272', series=change(fib1272)!=0?na:fib1272, style=linebr, color=olive)
plot(title='1.414', series=change(fib1414)!=0?na:fib1414, style=linebr, color=red)
plot(title='1.618', series=change(fib1618)!=0?na:fib1618, style=linebr, color=red)
plot(title='2.000', series=change(fib2000)!=0?na:fib2000, style=linebr, color=black, linewidth=2)
plot(title='2.272', series=change(fib2272)!=0?na:fib2272, style=linebr, color=olive)
plot(title='2.414', series=change(fib2414)!=0?na:fib2414, style=linebr, color=red)
plot(title='2.618', series=change(fib2618)!=0?na:fib2618, style=linebr, color=red)
plot(title='3.000', series=change(fib3000)!=0?na:fib3000, style=linebr, color=black, linewidth=2)
plot(title='3.272', series=change(fib3272)!=0?na:fib3272, style=linebr, color=olive)
plot(title='3.414', series=change(fib3414)!=0?na:fib3414, style=linebr, color=red)
plot(title='3.618', series=change(fib3618)!=0?na:fib3618, style=linebr, color=red)
plot(title='4.000', series=change(fib4000)!=0?na:fib4000, style=linebr, color=black, linewidth=2)
plot(title='4.236', series=change(fib4236)!=0?na:fib4236, style=linebr, color=olive)
plot(title='4.272', series=change(fib4272)!=0?na:fib4272, style=linebr, color=olive)
plot(title='4.414', series=change(fib4414)!=0?na:fib4414, style=linebr, color=red)
plot(title='4.618', series=change(fib4618)!=0?na:fib4618, style=linebr, color=red)
plot(title='4.764', series=change(fib4764)!=0?na:fib4764, style=linebr, color=aqua)

```
