---
id: PUB;1985
title: MACD trend heatmap (by ChartArt)
author: ChartArt
type: indicator
tags: []
boosts: 2642
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1985
---

# Description
MACD trend heatmap (by ChartArt)

# Source Code
```pine
//@version=2
study("MACD trend heatmap (by ChartArt)", shorttitle="CA_-_MACD_heat", overlay=true)

// ChartArt's MACD Trend Heatmap Overlay Indicator
//
// Version 1.0
// Idea by ChartArt on November 22, 2015.
//
// This is an overlay indicator which uses the classic 
// period settings and signals from the MACD
// (Moving Average Convergence/Divergence) indicator
// to overlay a heatmap using all the information
// the MACD generates with its three periods (12,26,9).
//
// The first two moving averages which the MACD uses
// (12 and 26) are plotted on the chart like usual EMAs.
//
// In addition to the background color (the heatmap) and
// the EMAs there is an optional bar color alert when the
// uptrend or the downtrend is very strong.
//
// List of my work: 
// https://www.tradingview.com/u/ChartArt/


// Input
fastlen = input(12, title="Fast Moving Average")
slowlen = input(26, title="Slow Moving Average")
signallen = input(9, title="Signal Line")
switch1=input(true, title="Enable Bar Color?")
switch2=input(true, title="Enable Moving Averages?")
switch3=input(true, title="Enable Heatmap?")

// Calculation
fast = ema(close,fastlen)
slow = ema(close,slowlen)
MACD = fast - slow
signal = ema(MACD, signallen)
histogr = MACD - signal

// MACD, MA colors
MACDcolor = fast > slow ? green : red
fastcolor = change(fast) > 0 ? green : red
slowcolor = change(slow) > 0 ? green : red
MACDupdowncolor = change(MACD) > 0 ? green : red

// MACD histogram colors
histogrMACDcolor = MACD > histogr ? green : red
histogrzerocolor = histogr > 0 ? green : red
histogrupdowncolor = change(histogr) > 0 ? green : red

// MACD signal line colors
signalMACDcolor = MACD > signal ? green : red
signalzerocolor = signal > 0 ? green : red
signalupdowncolor = change(signal) > 0 ? green : red

// Bar colors
MACDtrend = fast > slow and change(MACD) > 0 and histogr > 0 and change(histogr) > 0 and signal > 0 ? green : fast < slow and change(MACD) < 0 and histogr < 0 and change(histogr) < 0 and signal < 0 ? red : gray

// MA output
F=plot(switch2?fast:na,color=MACDcolor)
S=plot(switch2?slow:na,color=MACDcolor,linewidth=3)
fill(F,S,color=silver)

// Color output
bgcolor(switch3?MACDcolor:na,transp=98)
bgcolor(switch3?fastcolor:na,transp=98)
bgcolor(switch3?slowcolor:na,transp=98)
bgcolor(switch3?MACDupdowncolor:na,transp=98)
bgcolor(switch3?histogrMACDcolor:na,transp=98)
bgcolor(switch3?histogrzerocolor:na,transp=98)
bgcolor(switch3?histogrupdowncolor:na,transp=98)
bgcolor(switch3?signalMACDcolor:na,transp=98)
bgcolor(switch3?signalzerocolor:na,transp=98)
bgcolor(switch3?signalupdowncolor:na,transp=98)
barcolor(switch1?MACDtrend:na)
```
