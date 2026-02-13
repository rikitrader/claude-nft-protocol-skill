---
id: PUB;1122
title: RSI 100 150 200 MA Ribbon
author: QuantitativeExhaustion
type: indicator
tags: []
boosts: 984
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1122
---

# Description
RSI 100 150 200 MA Ribbon

# Source Code
```pine
study(title="RSI 100 150 200 MA", shorttitle="RSI 100 150 200 MA", overlay=false)
source = close

RSIFast  = rsi(source, input(100))
RSINorm  = rsi(source, input(150))
RSISlow = rsi(source, input(200))

plot(RSIFast, color=silver, style=area, histbase=50)
plot(RSINorm, color=#98b8be, style=area, histbase=50)
plot(RSISlow, color=#be9e98, style=area, histbase=50)

plot(RSIFast, color=gray, style=line, linewidth=1)
plot(RSINorm, color=purple, style=line, linewidth=2)
plot(RSISlow, color=black, style=line, linewidth=3)

exponential = input(true, title="Exponential MA")

src = (RSIFast)

ma05 = exponential ? ema(src, 05) : sma(src, 05)
ma30 = exponential ? ema(src, 30) : sma(src, 30)
ma50 = exponential ? ema(src, 50) : sma(src, 50)
ma70 = exponential ? ema(src, 70) : sma(src, 70)
ma90 = exponential ? ema(src, 90) : sma(src, 90)
ma100 = exponential ? ema(src, 100) : sma(src, 100)

leadMAColor = change(ma30)>=0 and ma30>ma100 ? lime
            : change(ma30)<0  and ma30>ma100 ? red
            : change(ma30)<=0 and ma30<ma100 ? maroon
            : change(ma30)>=0 and ma30<ma100 ? green
            : gray
maColor(ma, maRef) => 
              change(ma)>=0 and ma30>maRef ? lime
            : change(ma)<0  and ma30>maRef ? red
            : change(ma)<=0 and ma30<maRef ? maroon
            : change(ma)>=0 and ma30<maRef ? green
            : gray
            
plot( ma30, color=maColor(ma30,ma100), style=line, title="MMA30", linewidth=2)
plot( ma50, color=maColor(ma50,ma100), style=line, title="MMA50", linewidth=2)
plot( ma70, color=maColor(ma70,ma100), style=line, title="MMA70", linewidth=2)
plot( ma90, color=maColor(ma90,ma100), style=line, title="MMA90", linewidth=2)

exponential1 = input(true, title="Exponential MA")

src1 = (RSINorm)

ma051 = exponential1 ? ema(src1, 05) : sma(src1, 05)
ma301 = exponential1 ? ema(src1, 30) : sma(src1, 30)
ma501 = exponential1 ? ema(src1, 50) : sma(src1, 50)
ma701 = exponential1 ? ema(src1, 70) : sma(src1, 70)
ma901 = exponential1 ? ema(src1, 90) : sma(src1, 90)
ma1001 = exponential1 ? ema(src1, 100) : sma(src1, 100)

leadMAColor1 = change(ma051)>=0 and ma051>ma1001 ? lime
            : change(ma051)<0  and ma051>ma1001 ? red
            : change(ma051)<=0 and ma051<ma1001 ? maroon
            : change(ma051)>=0 and ma051<ma1001 ? green
            : gray
maColor1(ma, maRef) => 
              change(ma)>=0 and ma05>maRef ? lime
            : change(ma)<0  and ma05>maRef ? red
            : change(ma)<=0 and ma05<maRef ? maroon
            : change(ma)>=0 and ma05<maRef ? green
            : gray
            
plot( ma051, color=leadMAColor1, style=line, title="MMA05", linewidth=1)
plot( ma301, color=maColor1(ma301,ma1001), style=line, title="MMA30", linewidth=3)
plot( ma501, color=maColor1(ma501,ma1001), style=line, title="MMA50", linewidth=3)
plot( ma701, color=maColor1(ma701,ma1001), style=line, title="MMA70", linewidth=3)
plot( ma901, color=maColor1(ma901,ma1001), style=line, title="MMA90", linewidth=3)

exponential2 = input(true, title="Exponential MA")

src2 = (RSINorm)

ma052 = exponential2 ? ema(src2, 05) : sma(src2, 05)
ma302 = exponential2 ? ema(src2, 30) : sma(src2, 30)
ma502 = exponential2 ? ema(src2, 50) : sma(src2, 50)
ma702 = exponential2 ? ema(src2, 70) : sma(src2, 70)
ma902 = exponential2 ? ema(src2, 90) : sma(src2, 90)
ma1002 = exponential2 ? ema(src2, 100) : sma(src2, 100)

leadMAColor2 = change(ma052)>=0 and ma052>ma1002 ? lime
            : change(ma052)<0  and ma052>ma1002 ? red
            : change(ma052)<=0 and ma052<ma1002 ? maroon
            : change(ma052)>=0 and ma052<ma1002 ? green
            : gray
maColor2(ma, maRef) => 
              change(ma)>=0 and ma05>maRef ? lime
            : change(ma)<0  and ma05>maRef ? red
            : change(ma)<=0 and ma05<maRef ? maroon
            : change(ma)>=0 and ma05<maRef ? green
            : gray
            
plot( ma052, color=leadMAColor2, style=line, title="MMA05", linewidth=1)
plot( ma302, color=maColor2(ma302,ma1001), style=line, title="MMA30", linewidth=4)
plot( ma502, color=maColor2(ma502,ma1001), style=line, title="MMA50", linewidth=4)
plot( ma702, color=maColor2(ma701,ma1001), style=line, title="MMA70", linewidth=4)
plot( ma902, color=maColor2(ma901,ma1001), style=line, title="MMA90", linewidth=4)
```
