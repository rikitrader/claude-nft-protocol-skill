---
id: PUB;2755
title: ZeroLag ema + adx = true
author: TheYangGuizi
type: indicator
tags: []
boosts: 2500
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2755
---

# Description
ZeroLag ema + adx = true

# Source Code
```pine

//
study(title = "ZeroLag EMA+ADX=True", shorttitle="ZeroLagEMA_ADX", overlay=true)
len=input(20)
len2=input(50)
len3=input(200)
src=close
//EMA1
ema1=ema(src, len)
ema2=ema(ema1, len)
d=ema1-ema2
zlema=ema1+d
//EMA2
ema1b=ema(src, len2)
ema2b=ema(ema1b, len2)
db=ema1b-ema2b
zlemab=ema1b+db
//EMA3
ema1c=ema(src, len3)
ema2c=ema(ema1, len3)
dc=ema1c-ema2c
zlemac=ema1c+dc
//ADX
lenadx = input(14, minval=1, title="DI Length")
lensig = input(14, title="ADX Smoothing", minval=1, maxval=50)
limadx = input(18, minval=1, title="ADX MA Active")

up = change(high)
down = -change(low)
trur = rma(tr, lenadx)
plus = fixnan(100 * rma(up > down and up > 0 ? up : 0, lenadx) / trur)
minus = fixnan(100 * rma(down > up and down > 0 ? down : 0, lenadx) / trur)
sum = plus + minus 
adx = 100 * rma(abs(plus - minus) / (sum == 0 ? 1 : sum), lensig)

macol = adx > limadx and plus > minus ? lime : adx > limadx and plus < minus ? red :black
///ADX long

lenadxB = input(14, minval=1, title="DI Length")
lensigB = input(14, title="ADX Smoothing", minval=1, maxval=50)
limadxB = input(36, minval=1, title="ADX MA Active")

upB = change(high)
downB = -change(low)
trurB = rma(tr, lenadxB)
plusB = fixnan(100 * rma(upB > downB and upB > 0 ? up : 0, lenadxB) / trurB)
minusB = fixnan(100 * rma(downB > upB and downB > 0 ? downB : 0, lenadxB) / trurB)
sumB = plusB + minusB 
adxB = 100 * rma(abs(plusB - minusB) / (sumB == 0 ? 1 : sumB), lensigB)

macolB = adxB > limadxB and plusB > minusB ? lime : adxB > limadxB and plusB < minusB ? red :black

//
out = zlema
outb = zlemab
outc = zlemac
A1=plot(out, color=navy, title="MA", linewidth= 2)
A2=plot(outb, color=macol, title="MA2", linewidth= 2)
plot(outc, color=macolB, title="MA Long Term", linewidth= 2)
fill(A1, A2, color=gray, transp=75)
barcolor(adx > limadx and plus > minus ? lime : adx > limadx and plus < minus ? red :na, title="BC ADX")


```
