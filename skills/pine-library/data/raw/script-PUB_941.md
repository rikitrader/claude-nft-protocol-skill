---
id: PUB;941
title: [Bitcoin] Lastbattle's nose picker
author: LastBattle
type: indicator
tags: []
boosts: 927
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_941
---

# Description
[Bitcoin] Lastbattle's nose picker

# Source Code
```pine
study(title = "lastbattles nose picker", shorttitle="lastbattles nose picker",overlay=true)

// Inputs
rsiPeriod = input(14, title="RSI period")
//atrPeriod = input(20, title="ATR period")
overbought = input(67, title="Overbought Signal", minval=1, maxval=100)
oversold = input(35, title="Oversold Signal", minval=1, maxval=100)
volatilitymultiplier = input(1, title="Volatility multiplier", minval=0, maxval=5)

//atrTimeframe = input(defval="7", title="ATR Timeframe", type=resolution)
rsiTimeframe1 = input(defval="1", title="RSI Timeframe 1", type=resolution)
rsiTimeframe2 = input(defval="3", title="RSI Timeframe 2", type=resolution)
rsiTimeframe3 = input(defval="5", title="RSI Timeframe 3", type=resolution)
rsiTimeframe4 = input(defval="15", title="RSI Timeframe 4", type=resolution)
rsiTimeframe5 = input(defval="1", title="RSI Timeframe 5", type=resolution)
rsiTimeframe6 = input(defval="1", title="RSI Timeframe 6", type=resolution)

// Functions
isSellSignal(rsi1, rsi2, rsi3, rsi4, rsi5, rsi6, overbought) => (rsi1 >= overbought and rsi2 >= overbought and rsi3 >= overbought and rsi4 >= overbought and rsi5 >= overbought and rsi6 >= overbought)
isBuySignal(rsi1, rsi2, rsi3, rsi4, rsi5, rsi6, oversold) => (rsi1 <= oversold and rsi2 <= oversold and rsi3 <= oversold and rsi4 <= oversold and rsi5 <= oversold  and rsi6 <= oversold)

// RSI values
rsi1 = security(tickerid,rsiTimeframe1, rsi(close, rsiPeriod))
rsi2 = security(tickerid,rsiTimeframe2, rsi(close, rsiPeriod))
rsi3 = security(tickerid,rsiTimeframe3, rsi(close, rsiPeriod))
rsi4 = security(tickerid,rsiTimeframe4, rsi(close, rsiPeriod))
rsi5 = security(tickerid,rsiTimeframe5, rsi(close, rsiPeriod))
rsi6 = security(tickerid,rsiTimeframe6, rsi(close, rsiPeriod))

// ATR values in percentage wise
//atr = security(tickerid,atrTimeframe, ema(tr*100/close[1], atrPeriod))
//atr_percentagePrice = close[1] * 0.01 * atr
//multiplier_atr = abs(1 / (2 - atr_percentagePrice)) // absolute value of multiplier

// volatility switch
dr= security(tickerid,"60", roc(close,1)) / security(tickerid,"60", sma(close,2))
vola14=stdev(dr, 14)
vswitch14=((vola14[1] <= vola14 ) + (vola14[2] <= vola14 ) +   (vola14[3] <= vola14 ) +   
		(vola14[4] <= vola14 ) +  (vola14[5] <= vola14 ) + (vola14[6] <= vola14 ) +   
		(vola14[7] <= vola14 ) +  (vola14[8] <= vola14 ) +  (vola14[9] <= vola14 ) +  
		(vola14[10] <= vola14 ) + (vola14[11] <= vola14 ) +  (vola14[12] <= vola14 ) +  
		(vola14[13] <= vola14 ) + 1) / 14 
volatility_multiplier =  abs(1 / (volatilitymultiplier - vswitch14))

//plot(multiplier_atr + close, style=line,  linewidth=2, color=#FF0000)
//plot(atr_percentagePrice, style=line,  linewidth=2, color=#FF0000)
//plot(rsi1, style=line,  linewidth=2, color=#FF0000)
//plot(rsi2, style=line,  linewidth=2, color=#FF8000)
//plot(rsi3, style=line,  linewidth=2, color=#FFFF00)
//plot(rsi4, style=line,  linewidth=2, color=#80FF00)
//plot(rsi5, style=line,  linewidth=2, color=#00FFFF)
//plot(volatility_multiplier * 2 + close, color=red, linewidth=2, title="VOLSWITCH_21")

sellsignal = isSellSignal(rsi1, rsi2, rsi3, rsi4, rsi5, rsi6, overbought + volatility_multiplier)
buysignal = isBuySignal(rsi1, rsi2, rsi3, rsi4, rsi5, rsi6, oversold - (volatility_multiplier / 2))
spartasellsignal = isSellSignal(rsi1, rsi2, rsi3, rsi4, rsi5, rsi6, 80)
spartabuysignal = isBuySignal(rsi1, rsi2, rsi3, rsi4, rsi5, rsi6, 20)

// regular signals
plot(interval == 15 and sellsignal ? close : na, title="caution sell", color=red, style=columns, transp=50 , linewidth=7)
plot(interval == 15 and buysignal ? close : na, title="caution buy", color=green, style=columns, transp=50, linewidth=7)

// super signals! spartaaa
plot(interval == 15 and spartasellsignal ? close : na, title="super caution sell", color=red, style=columns, transp=0 , linewidth=7)
plot(interval == 15 and spartabuysignal ? close : na, title="super caution buy", color=green, style=columns, transp=0, linewidth=7)

//plotchar(isSellSignal(rsi1, rsi2, rsi3, rsi4, rsi5, overbought), char='S')
//plotchar(isBuySignal(rsi1, rsi2, rsi3, rsi4, rsi5, oversold), char='B')

//h1 = hline(0)
//h2 = hline(100)
//fill(h1, h2)
```
