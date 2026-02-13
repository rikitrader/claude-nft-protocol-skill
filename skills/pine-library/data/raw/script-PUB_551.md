---
id: PUB;551
title: UCSgears_Linear Regression Slope
author: UDAY_C_Santhakumar
type: indicator
tags: []
boosts: 687
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_551
---

# Description
UCSgears_Linear Regression Slope

# Source Code
```pine
// Created by UCSgears -- Version 1
// Simple linear regression slope - Good way see if the trend is accelarating or decelarating

study(title="UCSGEARS - Linear Regression Slope", shorttitle="UCS-LRS", overlay=false)
src = close
len = input(defval=5, minval=1, title="Slope Length")
lrc = linreg(src, 50, 0)
lrs = (lrc[-len] - lrc)/len
alrs = sma(lrs,9)
loalrs = sma(lrs,50)

uacce = lrs > alrs and lrs > 0 and lrs > loalrs
dacce = lrs < alrs and lrs < 0 and lrs < loalrs

scolor = uacce ? green : dacce ? red : blue

plot(lrs, color = scolor, title = "Linear Regression Slope", style = histogram, linewidth = 4)
plot(alrs, color = black, title = "Average Slope")
plot(0, title = "Zero Line")

```
