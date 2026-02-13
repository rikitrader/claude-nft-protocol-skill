---
id: PUB;774
title: Historical Volatility based Standard Deviation_V2
author: UDAY_C_Santhakumar
type: indicator
tags: []
boosts: 508
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_774
---

# Description
Historical Volatility based Standard Deviation_V2

# Source Code
```pine
//Created by UCSgears
//Plots Standard deviation on pricechart based on Historical Volatility. 
//This Code will be revised when Implied Volatility is available in trading view.

study(title="UCS_Standard Deviation-Historical Volatility_V2", shorttitle="UCS_StdDev(HV)", overlay = true)

length = input(10, minval=1)
DaystoExpire = input (30, minval=1) 
stddev1=input(true,title="Standard Deviation 1")
stddev2=input(true,title="Standard Deviation 2")
stddev3=input(false,title="Standard Deviation 3")
Smooth = input(true)
sm = input (21, title = "Smooth Length")

annual = 365
per = isintraday or isdaily and interval == 1 ? 1 : 7
hv = stdev(log(close / close[1]), length) * sqrt(annual / per)
stdhv = close*hv*sqrt(DaystoExpire/365) 
stdhv1 = Smooth ? sma(stdhv,sm) : stdhv
stdhv2 = stdhv1*2
stdhv3 = stdhv1*3

Stdhv1u = plot(stddev1 ? (close+stdhv1):na, color = red, title = "1st Standard Deviation Upperband")
Stdhv1d = plot(stddev1 ? (close-stdhv1):na, color = red, title = "1st Standard Deviation Lowerband")
Stdhv2u = plot(stddev2 ? (close+stdhv2):na, color = blue, title = "2nd Standard Deviation Upperband")
Stdhv2d = plot(stddev2 ? (close-stdhv2):na, color = blue, title = "2nd Standard Deviation Lowerband")
Stdhv3u = plot(stddev3 ? (close+stdhv3):na, color = black, title = "3rd Standard Deviation Upperband")
Stdhv3d = plot(stddev3 ? (close-stdhv3):na, color = black, title = "3rd Standard Deviation Lowerband")

```
