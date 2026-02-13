---
id: PUB;1369
title: Exponential Bollinger Bands
author: Rashad
type: indicator
tags: []
boosts: 1715
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1369
---

# Description
Exponential Bollinger Bands

# Source Code
```pine
study("Exponential Bollinger Bands", shorttitle = "EBB", overlay = true)
src = input(ohlc4, title = "source")
len = input(21, title = "timeframe / # of period's")
e = ema(src,len)
evar = (src - e)*(src - e)
evar2 = (sum(evar,len))/len
std = sqrt(evar2)
Multiplier = input(2, minval = 0.01, title = "# of STDEV's")
upband = e + (Multiplier * std)
dnband = e - (Multiplier * std)
//stdd = stdev(std)
//bsu = upband + std
//bsun = upband - std
//bsd = dnband + std
//bsdn = dnband - std
//plot(bsu, color = purple)
//plot(bsun, color = purple)
//plot(bsd, color = purple)
//plot(bsdn, color = purple)
plot(e, color = purple, linewidth = 2, title = "basis")
plot(upband, color = red, linewidth = 2, title = "up band")
plot(dnband, color = green, linewidth  = 2, title = "down band")
```
