---
id: PUB;1372
title: LBR PaintBars [LazyBear]
author: rmwaddelljr
type: indicator
tags: []
boosts: 219
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1372
---

# Description
LBR PaintBars [LazyBear]

# Source Code
```pine
//
// @author LazyBear
// List of all my indicators:
// https://docs.google.com/document/d/15AGCufJZ8CIUvwFJ9W-IKns88gkWOKBCvByMEvm5MLo/edit?usp=sharing
//
study("LBR PaintBars [LazyBear]", overlay=true, shorttitle="LBRBARS_LB")
lbperiod = input (16, title="HL Length")
atrperiod = input (9, title= "ATR Length")
stdev = input(20, title= "St Dev Length")
mult = input (2.5, minval=0, title="ATR Multiplier")
bcf = input(true, title="Color LBR Bars?")
mnlb=input(false, title="Color non LBR Bars?" )
svb=input(false, title="Show Volatility Bands?")
mkb=input(true, title="Mark LBR bars above/below KC?")
lengthKC = input(20, minval=1, title="KC Length")
multKC = input(1.5, title="KC Multiplier")
useTR = input(true, title="Use TR for KC")
skb=input(false, title="Show KC?")
calc_stdev(source, useTR, length, mult) =>
    ma = ema(source, length)
    range = useTR ? tr : high - low
    rangema = ema(range, length)
    upper = ma + rangema * mult
    lower = ma - rangema * mult
    [upper, ma, lower]
 
[u,b,l] = calc_stdev(close, useTR, lengthKC, multKC)
uk=plot(skb?u:na, color=gray, linewidth=1, title="KC Upper"), lk=plot(skb?l:na, color=gray, linewidth=1, title="KC Lower")
fill(uk,lk,gray), plot(skb?b:na, style=circles, color=orange, linewidth=2, title="KC Basis")
kct=mkb ? (close >= u or close <= l) : false
aatr = mult * sma(stdev(close,atrperiod), atrperiod)
b1 = lowest(low, lbperiod) + aatr
b2 = highest(high, lbperiod) - aatr
uvf =  (close > b1 and close > b2)
lvf = (close < b1 and close < b2 )
uv = plot(svb?b2:na, style=line, linewidth=3, color=red, title="UpperBand")
lv = plot(svb?b1:na, style=line, linewidth=3, color=green, title="LowBand")
bc = (bcf ? kct?fuchsia:(uvf ? lime : lvf ? maroon : mnlb?blue:na) : (not (uvf or lvf) and mnlb ? blue : na ) )
barcolor(bc)
```
