---
id: PUB;2282
title: Synthetic Vix Stochastic
author: ShirokiHeishi
type: indicator
tags: []
boosts: 262
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2282
---

# Description
Synthetic Vix Stochastic

# Source Code
```pine
//@version=2
//Author: ShirokiHeishi 
//Idea by Larry Williams, on his Synthetic vix formula based on the article in 
//ACTIVE TRADER www.activetradermag.com • December 2007 • pgs 24-32
//in his article he suggests that readings above 80 and below 20 are potential bottoming and topping zone.
study(title="Stochastic", shorttitle="WVF_Stoch")
//inputs
//Larry recommended 22 periods for the lookback
//Larry recommended 14 periods for the stochastic
pd = input(22, title="WVF lookback period")
length  = input(14, minval=1)
smoothK = input(1, minval=1)
smoothD = input(3, minval=1)
OB      = input(80, title="Topping Zone")
OS      = input(20, title="Bottoming Zone")
//definitions
//this inverts the output for a more tradional look to the Stochastics
wvf = ((highest(close, pd)-low)/(highest(close, pd)))* -1
vfh = highest(wvf,pd)
vfl = lowest(wvf,pd)
//Larry's original formula as recorded in the article
//WVF = (highest (close,22)- low)/(highest(close,22))*100
//uncomment for a more traditional reading similar to standard stochastics
// k   = sma(stoch(wvf, vfh, vfl, length), smoothK) 
k   = sma(stoch(wvf, wvf, wvf, length),smoothK)
d   = sma(k, smoothD)
// outputs
plot(k, color=white, transp=0, linewidth=2)
plot(d, color=maroon, transp=0, linewidth=2) 
h0 = hline(OB, linestyle=dotted, color=maroon, title="Potential Topping Zone")
h1 = hline(OS, linestyle=dotted, color=teal, title="Potential Bottoming Zone")
```
