---
id: PUB;1106
title: McClellan Oscillator [LazyBear]
author: LazyBear
type: indicator
tags: []
boosts: 2340
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1106
---

# Description
McClellan Oscillator [LazyBear]

# Source Code
```pine
//
// @author LazyBear 
// List of all my indicators: 
// https://docs.google.com/document/d/15AGCufJZ8CIUvwFJ9W-IKns88gkWOKBCvByMEvm5MLo/edit?usp=sharing
//
study("McClellan Oscillator [LazyBear]", shorttitle="MO_LB")
advissues=input(defval="ADVN", title="Advancing Stocks Symbol", type=symbol)
decissues=input(defval="DECN", title="Declining Stocks Symbol", type=symbol)
isRA=input(true, title="Stockcharts version (Ratio Adjusted)?")
rm=input(defval=1000, title="RANA ratio multiplier")
showEMAs=input(false, title="Show EMAs?")
showOsc=input(true, title="Show Oscillator?")

useCTF=input(false, title="Use Custom Timeframe?"), 
tf=useCTF?input("D", type=resolution, title="Custom Timeframe"):period
ai=security(advissues, tf, close), di=security(decissues, tf, close)
rana=rm * (ai-di)/(ai+di)
e1=isRA?ema(rana, 19):ema(ai-di, 19),e2=isRA?ema(rana, 39):ema(ai-di, 39)
mo=e1-e2

hline(0, title="ZeroLine")
plot(showOsc?mo<0?mo:0:na, style=area, color=red, title="MO_Negative")
plot(showOsc?mo>=0?mo:0:na, style=area, color=green, title="MO_Positive")
plot(showOsc?mo:na, style=line, color=black, title="MO", linewidth=2)
plot(showEMAs?e1:na, color=blue, linewidth=2, title="19 EMA")
plot(showEMAs?e2:na, color=red, linewidth=2, title="39 EMA")




```
