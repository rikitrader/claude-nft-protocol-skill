---
id: PUB;577
title: Linear Regression Slope - Version 2
author: UDAY_C_Santhakumar
type: indicator
tags: []
boosts: 2786
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_577
---

# Description
Linear Regression Slope - Version 2

# Source Code
```pine
// Created by UCSgears -- Version 2
// Simple linear regression slope - Good way see if the trend is accelarating or decelarating

study(title="UCSGEARS - Linear Regression Slope", shorttitle="UCS-LRS", overlay=false)

src = close
//Input
clen = input (defval = 50, minval = 1, title = "Curve Length")
slen = input(defval=5, minval=1, title="Slope Length")
glen = input(defval=13, minval=1, title="Signal Length")

//Linear Regression Curve
lrc = linreg(src, clen, 0)
//Linear Regression Slope
lrs = (lrc-lrc[1])/1
//Smooth Linear Regression Slope
slrs = ema(lrs, slen)
//Signal Linear Regression Slope
alrs = sma(slrs, glen)
//loalrs = sma(slrs, (glen*5))

uacce = lrs > alrs and lrs > 0 
dacce = lrs < alrs and lrs < 0 

scolor = uacce ? green : dacce ? red : blue

plot(0, title = "Zero Line", color = gray)
plot(slrs, color = scolor, title = "Linear Regression Slope", style = histogram, linewidth = 4)
plot(alrs, color = gray, title = "Average Slope")
```
