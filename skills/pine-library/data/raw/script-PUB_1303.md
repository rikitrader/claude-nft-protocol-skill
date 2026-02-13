---
id: PUB;1303
title: Zweig Market Breadth Thrust Indicator [LazyBear]
author: LazyBear
type: indicator
tags: []
boosts: 1348
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1303
---

# Description
Zweig Market Breadth Thrust Indicator [LazyBear]

# Source Code
```pine
//
// @author LazyBear 
// 
// List of my public indicators: http://bit.ly/1LQaPK8 
// List of my app-store indicators: http://blog.tradingview.com/?p=970 
//
study(title="Zweig Market Breadth Thrust Indicator [LazyBear]", shorttitle="ZMBTI_LB")
t=input(defval=2, maxval=2, minval=1, title="MA Type (1=>SMA, 2=>EMA)")
lma=input(defval=10, minval=1, title="MA Length")
mkt = input (defval=1, minval=0, maxval=4, title="Market (0=>AMEX/NASD/NYSE Combined, 1=NYSE, 2=NASDAQ, 3=AMEX, 4=CUSTOM)")
aic=input(defval="ADVS", title="CUSTOM: Advancing Stocks Symbol", type=symbol)
dic=input(defval="DECS", title="CUSTOM: Declining Stocks Symbol", type=symbol)
me=input(false, title="Color OB/OS")
ma(s,l) => t==1?sma(s,l):ema(s,l)	
res = "D"
advn="ADVN", decn="DECN" // NYSE
advnq="ADVQ", decnq="DECQ" // NASDAQ
advna="ADVA", decna="DECA" // AMEX
advc="(ADVN+ADVQ+ADVA)/3.0", decc="(DECN+DECQ+DECA)/3.0"
adv= security(mkt==0? advc:mkt == 1? advn:mkt == 2? advnq:mkt == 3? advna:aic, res, close)
dec= security(mkt==0? decc:mkt == 1? decn:mkt == 2? decnq:mkt == 3? decna:dic, res, close)
zmbti = ma(adv/(adv+dec), lma)
osl=plot(0.4, color=gray, title="OS"), obl=plot(0.615, color=gray, title="OB")
osd=plot(me?(zmbti<0.4?zmbti:0.4):na, style=circles, linewidth=0, title="DummyOS")
obd=plot(me?(zmbti>0.615?zmbti:0.615):na, style=circles, linewidth=0, title="DummyOB")
fill(osl,obl,black, title="RegionFill")
fill(osl, osd, green, transp=60, title="OSFill"), fill(obl, obd, red, transp=60, title="OBFill")
plot(zmbti, color=blue, linewidth=2, title="BreadthThrust")
```
