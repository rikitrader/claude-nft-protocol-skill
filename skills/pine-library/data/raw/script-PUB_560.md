---
id: PUB;560
title: UCSgears_Linear Regression Curve
author: UDAY_C_Santhakumar
type: indicator
tags: []
boosts: 670
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_560
---

# Description
UCSgears_Linear Regression Curve

# Source Code
```pine
// Created by UCSgears -- Version 1 
study(title="UCSGEARS - Linear Regression Curve", shorttitle="UCS-LRC", overlay=true)
src = close
len = input(defval=25, minval=1, title="Linear Regression Length")
lrc = linreg(src, len, 0)
plot(lrc, color = red, title = "Linear Regression Curve", style = line, linewidth = 2)
```
