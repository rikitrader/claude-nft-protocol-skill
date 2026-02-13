---
id: PUB;547
title: Bill Williams. Awesome Oscillator (AO) Signal Line
author: HPotter
type: indicator
tags: []
boosts: 3217
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_547
---

# Description
Bill Williams. Awesome Oscillator (AO) Signal Line

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v2.0 18/09/2014
//    This indicator is based on Bill Williams` recommendations from his book 
//    "New Trading Dimensions". We recommend this book to you as most useful reading.
//    The wisdom, technical expertise, and skillful teaching style of Williams make 
//    it a truly revolutionary-level source. A must-have new book for stock and 
//    commodity traders.
//    The 1st 2 chapters are somewhat of ramble where the author describes the 
//    "metaphysics" of trading. Still some good ideas are offered. The book references 
//    chaos theory, and leaves it up to the reader to believe whether "supercomputers" 
//    were used in formulating the various trading methods (the author wants to come across 
//    as an applied mathemetician, but he sure looks like a stock trader). There isn't any 
//    obvious connection with Chaos Theory - despite of the weak link between the title and 
//    content, the trading methodologies do work. Most readers think the author's systems to 
//    be a perfect filter and trigger for a short term trading system. He states a goal of 
//    10%/month, but when these filters & axioms are correctly combined with a good momentum 
//    system, much more is a probable result.
//    There's better written & more informative books out there for less money, but this author 
//    does have the "Holy Grail" of stock trading. A set of filters, axioms, and methods which are 
//    the "missing link" for any trading system which is based upon conventional indicators.
//    This indicator plots the oscillator as a histogram where periods fit for buying are marked 
//    as blue, and periods fit for selling as red. If the current value of AC (Awesome Oscillator) 
//    is over the previous, the period is deemed fit for buying and the indicator is marked blue. 
//    If the AC values is not over the previous, the period is deemed fir for selling and the indicator 
//    is marked red.
////////////////////////////////////////////////////////////
study("Bill Williams. Awesome Oscillator (AO) Signal Line")
nLengthSlow = input(34, minval=1, title="Length Slow")
nLengthFast = input(5, minval=1, title="Length Fast")
nLengthMA = input(15, minval=1, title="MA")
nLengthEMA = input(15, minval=1, title="EMA")
nLengthWMA = input(15, minval=1, title="WMA")
bShowWMA = input(type=bool, defval=true, title="Show WMA")
bShowMA = input(type=bool, defval=false, title="Show MA")
bShowEMA = input(type=bool, defval=false, title="Show EMA")
xSMA1_hl2 = sma(hl2, nLengthFast)
xSMA2_hl2 = sma(hl2, nLengthSlow)
xSMA1_SMA2 = xSMA1_hl2 - xSMA2_hl2
xResWMA = wma(xSMA1_SMA2, nLengthWMA)
xResMA = sma(xSMA1_SMA2, nLengthMA)
xResEMA = ema(xSMA1_SMA2, nLengthEMA)
cClr = xSMA1_SMA2 > xSMA1_SMA2[1] ? blue : red
plot(bShowWMA ? xResWMA : na, color = green)
plot(bShowMA ? xResMA : na, color = green)
plot(bShowEMA ? xResEMA : na, color = green)
plot(xSMA1_SMA2, style=histogram, linewidth=1, color=cClr)
```
