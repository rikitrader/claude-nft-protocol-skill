---
id: PUB;209
title: Indicator: Vervoort Smoothed Oscillator [LazyBear]
author: LazyBear
type: indicator
tags: []
boosts: 551
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_209
---

# Description
Indicator: Vervoort Smoothed Oscillator [LazyBear]

# Source Code
```pine
//
// @author LazyBear 
// List of all my indicators: https://www.tradingview.com/v/4IneGo8h/
//
study(title="Vervoort Smoothed Oscillator [LazyBear]", shorttitle="SV%BStoch_LB")
lengthStdev = input( 18, title="StdDev lookback")
mult=input(2.0, title="StDev Mult Factor")
smooth = input(3, title="calc_tema smoothing")
periodK = input(30, title="PeriodK")
smoothK = input(3, title="SmoothK")

calc_tema(src, length) =>
    e1 = ema(src, length)
    e2 = ema(e1, length)
    e3 = ema(e2, length)
    3 * (e1 - e2) + e3

sma2=sma(close,2)
dsma2=sma(sma2,2)
tsma2=sma(dsma2,2)
qsma2=sma(tsma2,2)
psma2=sma(qsma2,2)
ssma2=sma(psma2,2)
s2sma2=sma(ssma2,2)
osma2=sma(s2sma2,2)
o2sma2=sma(osma2,2)
desma2=sma(o2sma2,2)
rainbow = (5*sma2+4*dsma2+3*tsma2+2*qsma2+psma2+ssma2+s2sma2+osma2+o2sma2+desma2)/20
ema1 = ema( rainbow, smooth ) 
ema2 = ema( ema1, smooth ) 
zlrb = 2 * ema1 - ema2  
tz = calc_tema( zlrb, smooth ) 
hwidth = stdev( tz, lengthStdev ) 
zlrbpercb = (tz + mult*hwidth  - wma(tz,lengthStdev)) / (2*mult*hwidth)*100
rbc = avg(rainbow, hlc3)
nom = rbc - lowest( low, periodK ) 
den = highest( high, periodK ) - lowest( rbc, periodK ) 
//fastK = 100*nom/den // No Stoch clipping version
fastK = min( 100, max( 0, 100 * nom/den ) ) 

hline(0)
hline(50)
hline(100)

slowKOBLevel=input(80)
slowKOSLevel=input(20)
sk=sma( fastK, smoothK )
bs = (sk > slowKOBLevel) ? slowKOBLevel : sk
us = (sk < slowKOSLevel) ? slowKOSLevel : sk
bl=plot(bs, color=red, style=circles, linewidth=0)
ul=plot(us, color=red, style=circles, linewidth=0)
tl=plot( sk, title="SlowK", color=red, linewidth=2 )
fill(bl, tl, color=red, transp=90)
fill(ul, tl, color=blue, transp=90)
plot( zlrbpercb , title="Zero Lag Rainbow %B", color=blue, linewidth=2 ) 
```
