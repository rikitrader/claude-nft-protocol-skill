---
id: PUB;3130
title: Ichimoku Timeframe 6.0
author: walkman
type: indicator
tags: []
boosts: 604
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_3130
---

# Description
Ichimoku Timeframe 6.0

# Source Code
```pine
//Created by @TraderR0BERT, NETWORTHIE.COM, last updated 05/19/2016
//Ichimoku Cloud Indicator
//Resolution input option for higher/lower time frames
//Alerts for common ichimoku trading signals (TS & KS Cross, Kumo Breakout, Kumo Twist)

study(title="Ichimoku Timeframe 6.0", shorttitle="Ichimoku TF 6.0", overlay=true)

Ten = input(9, minval=1, title="Tenkan")
Kij = input(26, minval=1, title="Kijun")
LeadSpan = input(52, minval=1, title="Senkou B")
Displace = input(26, minval=1, title="Senkou A")
SpanOffset = input(26, minval=1, title="Span Offset")

timeframe = input(title="Timeframe", type=resolution, defval="60")
sts = input(false, title="Show Tenkan")
sks = input(false, title="Show Kijun")
ssa = input(true, title="Show Span A")
ssb = input(true, title="Show Span B")

source = close

//Script for Ichimoku Indicator
donchian(len) => avg(lowest(len), highest(len))
TS = donchian(Ten)
KS = donchian(Kij)
SpanA = avg(TS, KS)
SpanB = donchian(LeadSpan)
Chikou = source[Displace]
SpanAA = avg(TS, KS)[SpanOffset]
SpanBB = donchian(LeadSpan)[SpanOffset]

//Kumo Breakout (Long)
SpanA_Top = SpanAA >= SpanBB ? 1 : 0
SpanB_Top = SpanBB >= SpanAA ? 1 : 0

SpanA_Top2 = SpanA >= SpanB ? 1 : 0
SpanB_Top2 = SpanB >= SpanA ? 1 : 0

SpanA1 = SpanA_Top2 ? SpanA : na
SpanA2 = SpanA_Top2 ? SpanB : na

SpanB1 = SpanB_Top2 ? SpanA : na
SpanB2 = SpanB_Top2 ? SpanB : na

//plot for Tenkan and Kijun (Current Timeframe)
p1= plot(sts and TS ? TS : na, title="Tenkan", linewidth = 2, color = blue)
p2 = plot(sks and KS ? KS : na, title="Kijun", linewidth = 2, color = purple)
p5 = plot(close, title="Chikou", linewidth = 2, offset=-Displace, color = black)

//Plot for Kumo Cloud (Dynamic Color)
p3 = plot(ssa and SpanA ? SpanA : na, title="SpanA", linewidth=2, offset=Displace, color=green)
p4 = plot(ssb and SpanB ? SpanB : na, title="SpanB", linewidth=2, offset=Displace, color=red)

p8 = plot(ssa and SpanA1 ? SpanA1 : na, title="Span A1 above", style=linebr, linewidth=1, offset=Displace, color=green)
p9 = plot(ssa and SpanA2 ? SpanA2 : na, title="Span A2 above", style=linebr, linewidth=1, offset=Displace, color=green)
p10 = plot(ssb and SpanB1 ? SpanB1 : na, title="Span B1 above", style=linebr, linewidth=1, offset=Displace, color=red)
p11 = plot(ssb and SpanB2 ? SpanB2 : na, title="Span B2 above", style=linebr, linewidth=1, offset=Displace, color=red)

fill(p8, p9, color = lime, transp=70, title="Kumo Cloud Up")
fill (p10, p11, color=red, transp=70, title="Kumo Cloud Down")

LongSpan = (SpanA_Top and source[1] < SpanAA[1] and source > SpanAA) or (SpanB_Top and source[1] < SpanBB[1] and source > SpanBB) ? 1 : 0
cupSpan = LongSpan  == 1 ? LongSpan : 0

//Kumo Breakout (Long)
plotarrow(cupSpan, title="Kumo Breakout Long", colorup=green, maxheight=90)

//Kumo Breakout (Long) Alerts
Long_Breakout = (SpanA_Top ==1 and crossover(source, SpanAA)) or (SpanB_Top ==1 and crossover(source, SpanBB))
alertcondition(Long_Breakout, title="Kumo Breakout Long", message="Kumo Long")

//Kumo Breakout (Short)
ShortSpan = (SpanB_Top and source[1] > SpanAA[1] and source < SpanAA) or (SpanA_Top and source[1] > SpanBB[1] and source < SpanBB) ? 1 : 0
cdnSpan = ShortSpan == 1 ? ShortSpan : 0

//Kumo Breakout (Short)
plotarrow(cdnSpan*-1, title="Kumo Breakout Short", colordown=red, maxheight=90)

//Kumo Breakout (Short) Alerts
Short_Breakout = (SpanA_Top ==1 and crossunder(source, SpanBB)) or (SpanB_Top ==1 and crossunder(source, SpanAA))
alertcondition(Short_Breakout, title="Kumo Breakout Short", message="Kumo Short")

//Kumo Twist
Kumo_Twist_Long = SpanA[1] < SpanB[1] and SpanA > SpanB ? 1 : 0
Kumo_Twist_Short = SpanA[1] > SpanB[1] and SpanA < SpanB ? 1 : 0

cupD = Kumo_Twist_Long == 1 ? Kumo_Twist_Long : 0
cdnD = Kumo_Twist_Short == 1 ? Kumo_Twist_Short : 0

//Kumo Twist (Long/Short)
plotarrow(cupD, title="Kumo Twist Long", colorup=green, maxheight=50)
plotarrow(cdnD*-1, title="Kumo Twist Short", colordown=red, maxheight=50)

//Kumo Twist (Long/Short) Alerts
KumoTwistLong_Cross = crossover(SpanA, SpanB)
alertcondition(KumoTwistLong_Cross, title="Kumo Twist Long", message="Kumo Twist Long")
KumoTwistShort_Cross = crossunder(SpanA, SpanB)
alertcondition(KumoTwistShort_Cross, title="Kumo Twist Short", message="Kumo Twist Short")

//Kumo Twist (Long/Short) - Bar Color
BarColor = Kumo_Twist_Long ? green : Kumo_Twist_Short ? red : na
barcolor(BarColor)

//Chikou above/below Price
Chikou_Above = close > Chikou
Chikou_Below = close < Chikou


//Kumo Twist (Long/Short) - Plot Character on location of Chikou to Price & Price to Kumo
plotchar(Kumo_Twist_Long and Chikou_Above, title="Kumo Twist Long and Chikou above Price", char="A", location=location.abovebar, color=green)
plotchar(Kumo_Twist_Long and Chikou_Below, title="Kumo Twist Long and Chikou below Price", char="B", location=location.abovebar, color=red)
plotchar(Kumo_Twist_Short and Chikou_Above, title="Kumo Twist Short and Chikou above Price", char="A", location=location.belowbar, color=green)
plotchar(Kumo_Twist_Short and Chikou_Below, title="Kumo Twist Short and Chikou below Price", char="B", location=location.belowbar, color=red)   
plotchar(Chikou_Above, title="Chikou above Price", char="O",location=location.abovebar, color=green)
plotchar(Chikou_Below, title="Chikou under Price", char="U",location=location.belowbar, color=red)


//Crosses Tenkan and Kijun (Arrows)
crossUpTSKS = TS[1] < KS[1] and TS > KS ? 1 : 0
crossDnTSKS = TS[1] > KS[1] and TS < KS ? 1 : 0
cupA = crossUpTSKS == 1 ? crossUpTSKS : 0
cdnA = crossDnTSKS == 1 ? crossDnTSKS : 0

//Plots Tenkan and Kijun Cross
plotarrow(cupA, title="CrossUp Tenkan Kinjun", colorup=blue, maxheight=50, minheight=50, transp=0)
plotarrow(cdnA*-1, title="CrossDn Tenkan Kinjun", colordown=purple, maxheight=50, minheight=50, transp=0)



```
