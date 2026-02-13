---
id: PUB;1316
title: MACD Color Trawler (by ChartArt)
author: ChartArt
type: indicator
tags: []
boosts: 2091
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1316
---

# Description
MACD Color Trawler (by ChartArt)

# Source Code
```pine
study(title="MACD Color Trawler (by ChartArt)", shorttitle="CA_-_MACD_CT")

// Version 1.0
// Idea by ChartArt on May 12, 2015.
//
// The indicator is 'trawling' (checking) if the MACD histogram
// and the zero line crossing with the MACD line
// are both positive or negative.
// 
// List of my work: 
// https://www.tradingview.com/u/ChartArt/

source = close
fastLength = input(12, minval=1), slowLength=input(26,minval=1)
signalLength=input(9,minval=1)
fastMA = ema(source, fastLength)
slowMA = ema(source, slowLength)
macd = fastMA - slowMA
signal = sma(macd, signalLength)
hist = macd - signal

switch1=input(true, title="Enable Bar Color?")
switch2=input(true, title="Enable Background Color?")

plot(macd, color=blue,linewidth=2)
plot(signal, color=gray,linewidth=1)

// Histogram Color
GetHistogramColor =	iff(hist > 0, 1,
	                iff(hist < 0, -1, nz(GetHistogramColor[1], 0))) 
ColorHistogram = GetHistogramColor == -1 ? red: GetHistogramColor == 1 ? green : blue 
plot(hist, color=ColorHistogram, style=histogram,linewidth=4)

// Bar Color
Trigger = input(0, title="Zeroline Trigger Value?")
GetBarColor =	iff((macd > Trigger) and (hist > 0), 1,
	            iff((macd < Trigger) and (hist < 0), -1, nz(GetBarColor[1], 0)))
SelectBarColor = GetBarColor == -1 ? red: GetBarColor == 1 ? green: blue
barcolor(switch1?SelectBarColor:na)

// Background Color
GetBackgroundColor =	iff((macd > Trigger) and (hist > 0), 1,
	                    iff((macd < Trigger) and (hist < 0), -1, nz(GetBackgroundColor[1], 0)))
SelectBackgroundColor = GetBackgroundColor == -1 ? red: GetBackgroundColor == 1 ? green: blue
bgcolor(switch2?SelectBackgroundColor:na, transp=90)


```
