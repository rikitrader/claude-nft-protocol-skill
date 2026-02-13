---
id: PUB;552
title: Linear Regression Slope
author: UDAY_C_Santhakumar
type: indicator
tags: []
boosts: 402
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_552
---

# Description
Linear Regression Slope

# Source Code
```pine
// Created by UCSgears -- Version 1 (redone)
// Simple linear regression slope - Good way see if the trend is accelarating or decelarating

study(title="UCSGEARS - Linear Regression Slope", shorttitle="UCS-LRS", overlay=false)
src = close
len = input(defval=5, minval=1, title="Slope Length")
lrc = linreg(src, 50, 0)
lrs = (lrc-lrc[len])/len
alrs = sma(lrs,9)
loalrs = sma(lrs,50)

uacce = lrs > alrs and lrs > 0 and lrs > loalrs
dacce = lrs < alrs and lrs < 0 and lrs < loalrs

scolor = uacce ? green : dacce ? red : blue

plot(lrs, color = scolor, title = "Linear Regression Slope", style = histogram, linewidth = 4)
plot(alrs, color = white, title = "Average Slope")
plot(0, title = "Zero Line", color = white)

```
