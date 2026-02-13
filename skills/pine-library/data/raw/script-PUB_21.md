---
id: PUB;21
title: Indicator: 4MACD 
author: LazyBear
type: indicator
tags: []
boosts: 2218
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_21
---

# Description
Indicator: 4MACD 

# Source Code
```pine
//
// @author LazyBear
//
study(title = "4MACD [LazyBear]", shorttitle="4MACD_LB")

source=close
mult_b=input(4.3, title="Blue multiplier")
mult_y=input(1.4, title="Yellow multiplier")

ema5=ema(close,5)
ema8=ema(close,8)
ema10=ema(close,10)
ema17=ema(source,17)
ema14=ema(source,14)
ema16=ema(close,16)
ema17_14 = ema17-ema14
ema17_8=ema17-ema8
ema10_16=ema10-ema16
ema5_10=ema5-ema10

MACDBlue=mult_b*(ema17_14-ema(ema17_14,5))
MACDRed=ema17_8-ema(ema17_8,5)
MACDYellow=mult_y*(ema10_16-ema(ema10_16,5))
MACDGreen=ema5_10-ema(ema5_10,5)

plot(MACDBlue, style=histogram, color=#0066cc, linewidth=4)
plot(MACDRed, style=histogram, color=red, linewidth=4)
plot(MACDYellow, style=histogram, color=yellow, linewidth=4)
plot(MACDGreen, style=histogram, color=green, linewidth=4)
```
