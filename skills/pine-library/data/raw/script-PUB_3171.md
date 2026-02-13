---
id: PUB;3171
title: ZigZag Advance Pattern from Santos + My BB500.2 Study
author: senpai
type: indicator
tags: []
boosts: 1331
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_3171
---

# Description
ZigZag Advance Pattern from Santos + My BB500.2 Study

# Source Code
```pine
study("[RS]ZigZag PA V4 Advanced Patterns V0.01", overlay=true)
useHA = input(false, title='Use Heikken Ashi Candles')
useAltTF = input(true, title='Use Alt Timeframe')
tf = input('60', title='Alt Timeframe')
showPatterns = input(true, title='Show Patterns')
showFib0000 = input(title='Display Fibonacci 0.000:', type=bool, defval=true)
showFib0236 = input(title='Display Fibonacci 0.236:', type=bool, defval=true)
showFib0382 = input(title='Display Fibonacci 0.382:', type=bool, defval=true)
showFib0500 = input(title='Display Fibonacci 0.500:', type=bool, defval=true)
showFib0618 = input(title='Display Fibonacci 0.618:', type=bool, defval=true)
showFib0764 = input(title='Display Fibonacci 0.764:', type=bool, defval=true)
showFib1000 = input(title='Display Fibonacci 1.000:', type=bool, defval=true)
zigzag() =>
    _isUp = close >= open
    _isDown = close <= open
    _direction = _isUp[1] and _isDown ? -1 : _isDown[1] and _isUp ? 1 : nz(_direction[1])
    _zigzag = _isUp[1] and _isDown and _direction[1] != -1 ? highest(2) : _isDown[1] and _isUp and _direction[1] != 1 ? lowest(2) : na

_ticker = useHA ? heikenashi(tickerid) : tickerid
sz = useAltTF ? (change(time(tf)) != 0 ? security(_ticker, tf, zigzag()) : na) : zigzag()

plot(sz, title='zigzag', color=black, linewidth=2)

//  ||---   Pattern Recognition:

z = valuewhen(sz, sz, 6) 
y = valuewhen(sz, sz, 5) 
x = valuewhen(sz, sz, 4) 
a = valuewhen(sz, sz, 3) 
b = valuewhen(sz, sz, 2)
c = valuewhen(sz, sz, 1)
d = valuewhen(sz, sz, 0)

zyx = (abs(x-y)/abs(z-y))
zyb = (abs(b-y)/abs(z-y))
zyd = (abs(d-y)/abs(z-y))
zab = (abs(b-a)/abs(z-a))
zad = (abs(d-a)/abs(z-a))
zcd = (abs(d-c)/abs(z-c))

yxa = (abs(a-x)/abs(y-x))
yxc = (abs(c-x)/abs(y-x))
ybc = (abs(a-c)/abs(y-c))

xab = (abs(b-a)/abs(x-a))
xad = (abs(a-d)/abs(x-a))
abc = (abs(b-c)/abs(a-b))
bcd = (abs(c-d)/abs(b-c))
//  ||-->   Functions:

isABCD(_mode)=>
    _abc = abc >= 0.382 and abc <= 0.886
    _bcd = bcd >= 1.13 and bcd <= 2.618
    _abc and _bcd and (_mode == 1 ? d < c : d > c)

isBat(_mode)=>
    _xab = xab >= 0.382 and xab <= 0.5
    _abc = abc >= 0.382 and abc <= 0.886
    _bcd = bcd >= 1.618 and bcd <= 2.618
    _xad = xad <= 0.618 and xad <= 1.000    // 0.886
    _xab and _abc and _bcd and _xad and (_mode == 1 ? d < c : d > c)

is3Drive(_mode)=>
    _zyx = zyx >= 0.236 and zyx < 1.000
    //_zyb = zyb >= 0.236 and zyb < 0.382
    //_zyd = zyd >= 0.236 and zyd < 0.382
    //_zab = zab >= 0.236 and zab < 0.382
    //_zad = zad >= 0.236 and zad < 0.382
    //_zcd = zcd >= 0.236 and zcd < 0.382
    _yxa = yxa >= 1.000 and yxa < 9.999
    //_yxc = yxc >= 0.236 and yxc < 0.382
    //_ybc = ybc >= 0.236 and ybc < 0.382
    _xab = xab >= 0.236 and xab < 1.000
    _abc = abc >= 1.000 and abc < 9.999
    _bcd = bcd >= 0.236 and bcd < 1.000
    //_xad = xad <= 0.618 and xad < 1.000    // 0.886
    _zyx and _yxa and _xab and _abc and _bcd and (_mode == 1 ? d < c : d > c)

plotshape(not showPatterns ? na : change(isABCD(-1)) > 0, text="\nAB=CD", title='Bear ABCD', style=shape.labeldown, color=maroon, textcolor=white, location=location.top, transp=0)
plotshape(not showPatterns ? na : change(isBat(-1)) > 0, text="Bat", title='Bear Bat', style=shape.labeldown, color=maroon, textcolor=white, location=location.top, transp=0)
plotshape(not showPatterns ? na : change(is3Drive(-1)) > 0, text="3Driver", title='Bear 3 Driver', style=shape.labeldown, color=maroon, textcolor=white, location=location.top, transp=0)

plotshape(not showPatterns ? na : change(isABCD(1)) > 0, text="AB=CD\n", title='Bull ABCD', style=shape.labelup, color=green, textcolor=white, location=location.bottom, transp=0)
plotshape(not showPatterns ? na : change(isBat(1)) > 0, text="Bat", title='Bull Bat', style=shape.labelup, color=green, textcolor=white, location=location.bottom, transp=0)
plotshape(not showPatterns ? na : change(is3Drive(1)) > 0, text="3Driver", title='Bull 3 Driver', style=shape.labelup, color=green, textcolor=white, location=location.bottom, transp=0)

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
fib_range = abs(d-c)
fib_0000 = not showFib0000 ? na : d > c ? d-(fib_range*0.000):d+(fib_range*0.000)
fib_0236 = not showFib0236 ? na : d > c ? d-(fib_range*0.236):d+(fib_range*0.236)
fib_0382 = not showFib0382 ? na : d > c ? d-(fib_range*0.382):d+(fib_range*0.382)
fib_0500 = not showFib0500 ? na : d > c ? d-(fib_range*0.500):d+(fib_range*0.500)
fib_0618 = not showFib0618 ? na : d > c ? d-(fib_range*0.618):d+(fib_range*0.618)
fib_0764 = not showFib0764 ? na : d > c ? d-(fib_range*0.764):d+(fib_range*0.764)
fib_1000 = not showFib1000 ? na : d > c ? d-(fib_range*1.000):d+(fib_range*1.000)
plot(title='Fib 0.000', series=fib_0000, color=fib_0000 != fib_0000[1] ? na : black)
plot(title='Fib 0.236', series=fib_0236, color=fib_0236 != fib_0236[1] ? na : red)
plot(title='Fib 0.382', series=fib_0382, color=fib_0382 != fib_0382[1] ? na : olive)
plot(title='Fib 0.500', series=fib_0500, color=fib_0500 != fib_0500[1] ? na : lime)
plot(title='Fib 0.618', series=fib_0618, color=fib_0618 != fib_0618[1] ? na : teal)
plot(title='Fib 0.764', series=fib_0764, color=fib_0764 != fib_0764[1] ? na : blue)
plot(title='Fib 1.000', series=fib_1000, color=fib_1000 != fib_1000[1] ? na : black)
```
