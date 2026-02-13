---
id: PUB;928
title: Pivot Boss 4 EMA
author: DavidR.
type: indicator
tags: []
boosts: 3917
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_928
---

# Description
Pivot Boss 4 EMA

# Source Code
```pine
// Pivot Boss is based on the work of Frank Ochoa @ www.pivotboss.com
// Converted to Pinescript from Easy Language by DavidR.


// Summary:
// Creates one indicator with three exponential moving averages based off the central pivot point
// which assists you in trading pure price action using floor pivots.
// This also helps you to avoid getting chopped up during price confluence.

// Parameters:
// ShortEMA – Number of periods used to calculate the short term moving average.
// MedEMA   – Number of periods used to calculate the medium term moving average.
// LongEMA  – Number of periods used to calculate the long term moving average. 

// How to use:
// When T-Line cross Green Short EMA it can be used for scalping.
// When Short EMA pulls back to Medium EMA you can buy more or sell more depending on 
// without having to exit your position prematurely before trend direction changes.
// This can also be used as position entry points to make sure you are getting the best possible price.
// When T-Line, Short EMA and Medium EMA cross over Long EMA you go long or short.


study(title="Pivot Boss 4 EMA", shorttitle="Pivot Boss 4 EMA", overlay=true)
src = close

TLineEMA = input(8, minval=1, title="Trigger Line")
ShortEMA = input(13, minval=1, title="Short EMA")
MedEMA   = input(34, minval=1, title="Medium EMA")
LongEMA  = input(55, minval=1, title="Long EMA")

fPivot = ((high + low + close)/3)

TLine       = ema(close, TLineEMA)
fShortEMA   = ema(fPivot, ShortEMA)
fMedEMA     = ema(fPivot, MedEMA)
fLongEMA    = ema(fPivot, LongEMA)

plot(TLine, color=yellow, title="T-Line EMA", linewidth=2)
plot(fShortEMA, color=green, title="Short EMA", linewidth=2)
plot(fMedEMA, color=gray, title="Medium EMA", linewidth=2)
plot(fLongEMA, color=maroon, title="Long EMA", linewidth=2)
```
