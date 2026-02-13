---
id: PUB;1652
title: Volume Pressure Composite Average with Bands by @XeL_Arjona
author: xel_arjona
type: indicator
tags: []
boosts: 506
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1652
---

# Description
Volume Pressure Composite Average with Bands by @XeL_Arjona

# Source Code
```pine
//	* VOLUME PRESSURE -COMPOSITE- WEIGHTED MOVING AVERAGE
//    Ver. 1.0.beta.10.08.2015
//    By Ricardo M Arjona @XeL_Arjona
//	
//		DISCLAIMER:
//
//      The Following indicator/code IS NOT intended to be
//      a formal investment advice or recommendation by the
//      author, nor should be construed as such. Users
//      will be fully responsible by their use regarding 
//      their own trading vehicles/assets.
//
//		The embedded code and ideas within this work are 
//		FREELY AND PUBLICLY available on the Web
//		for NON LUCRATIVE ACTIVITIES and must remain as is.
//
//		Pine Script code MOD's and adaptations by @XeL_Arjona 
//      with special mention in regard of:
//      + Buy (Bull) and Sell (Bear) "Power Balance Algorithm" by:
//          Stocks & Commodities V. 21:10 (68-72):
//          "Bull And Bear Balance Indicator by Vadim Gimelfarb"
//      + Normalisation (Filter) from Karthik Marar's VSA work:
//          http://karthikmarar.blogspot.mx
//      + Adjusted Exponential Adaptation from original Volume
//          Weighted Moving Average (VEMA) by @XeL_Arjona with
//          commited help at the @pinescript chat room help
//          with special mention to @RicardoSantos
//      + Color Cloud Fill Condition algorithm by @ChrisMoody
//
//      WHAT IS THIS?
//
//      The following indicators try to acknowledge in a K-I-S-S
//      approach to the eye (Keep-It-Simple-Stupid), the two most
//      important aspects of nearly every trading vehicle:
//           -- PRICE ACTION IN RELATION BY IT'S VOLUME --
//
//      A) My approach is to make this indicator both as a "Trend Follower"
//      as well as a Volatility expressed in the Bands which are the weighting
//      basis of the trend given their "Cross Signal" given by
//      the Buy & Sell Volume Pressures algorithm.
//           << THEIR USE MUST BE CONSIDERED AS EXPERIMENTAL !! >>
//
//      B) Please experiment with lookback periods against different
//      timeframes. Given the nature of the Volume Mathematical Monster
//      this kind of stydie is and in concordance with Price Action;
//      at first glance I've noted that both in short as in long term
//      periods, the indicator tends to adapt quite well to general
//      price action conditions.  BE ADVICED THIS IS EXPERIMENTAL!
//
//      C) ALL NEW IDEAS OR MODIFICATIONS to these indicator(s) are
//      Welcome in favor to deploy a better and more accurate readings.
//      I will be very glad to be notified at Twitter or TradingVew
//      accounts at:   @XeL_Arjona
//
//      Any important adition to this work MUST REMAIN
//      PUBLIC by means of CreativeCommons CC & TradingView.
//      2015
//		
//////////////////////////////////////////////////////////////////
study("VOLUME PRESSURE -COMPOSITE- WEIGHTED MOVING AVERAGE by @XeL_Arjona", shorttitle="VPMA_XeL", overlay=true)
p = input(title="Lookback Periods:", defval=21)
bands = input(false, title="Show Pressure Bands:")
colb = input(true, title="Color Trend on price bars:")
// MAIN GENERAL VARIABLES/FUNCTIONS
vol = iff(volume>0 ,volume, 1)
vema(array,periods,K) =>
    VolW = vol*array
    VolK = K/(periods+1)
    VMsma = sum((VolW),periods)/sum(vol,periods)
    VMema = na(VMema[1]) ? (VMsma*VolK) : ((VolW-VMema[1])*VolK)+VMema[1]
// Close Conditions for Pressure Algorithms
cl = close
op = open
hi = high
lo = low
// Bull And Bear "Power-Balance" by Vadim Gimelfarb Algorithm's
BP =    iff(cl<op,          iff(cl[1]<op,   max(hi-cl[1], cl-lo), 
                                            max(hi-op, cl-lo)),
        iff(cl>op,          iff(cl[1]>op,   hi-lo, 
                                            max(op-cl[1], hi-lo)),
        iff(hi-cl>cl-lo,    iff(cl[1]<op,   max(hi-cl[1],cl-lo),
                                            hi-op),
        iff(hi-cl<cl-lo,    iff(cl[1]>op,   hi-lo,
                                            max(op-cl[1], hi-lo)),
        iff(cl[1]>op,       max(hi-op, cl-lo),
        iff(cl[1]<op,       max(op-cl[1], hi-lo),
        hi-lo))))))
SP =    iff(cl<op,          iff(cl[1]>op,   max(cl[1]-op, hi-lo),
                                            hi-lo),
        iff(cl>op,          iff(cl[1]>op,   max(cl[1]-lo, hi-cl),
                                            max(op-lo, hi-cl)),
        iff(hi-cl>cl-lo,    iff(cl[1]>op,   max(cl[1]-op, hi-lo),
                                            hi-lo),
        iff(hi-cl<cl-lo,    iff(cl[1]>op,   max(cl[1]-lo, hi-cl),
                                            op-lo),
        iff(cl[1]>op,       max(cl[1]-op, hi-lo),
        iff(cl[1]<op,       max(op-lo, hi-cl),
        hi-lo))))))
TP = BP+SP
// GENERAL CALCULATION VARIABLES FOR STUDIES
BPV = (BP/TP)*vol
SPV = (SP/TP)*vol
TPV = BPV+SPV
TH  = max(high, close[1])
TL  = min(low, close[1])
BPP = (TL+close)/2
SPP = (TH+close)/2
// Volume Pressures Weighted Averages
bpMavg = vema((BPV*BPP),p,3) / vema(TPV,p,3)*2
spMavg = vema((SPV*SPP),p,3) / vema(TPV,p,3)*2
VPMavg = (bpMavg+spMavg)/2
VPMAc = bpMavg > VPMavg ? green : red
// PLOT DIRECTIVES
//Cloud coloring method by @ChrisMoody
BPAbove = bpMavg >= spMavg ? 1 : na
SPBelow = bpMavg <= spMavg ? 1 : na
BPplotU = BPAbove ? bpMavg : na
SPplotU = BPAbove ? spMavg : na
BPplotD = SPBelow ? bpMavg : na
SPplotD = SPBelow ? spMavg : na
// Standard Line Coloring
CondCol = bpMavg > spMavg ? green : red
//Center Avg Line
plot(bands?na:VPMavg, color=CondCol, title='VPMA', style=line, linewidth=2)
//Cloud Lines Plot Statements - ***linebr to create rules for change in Shading
p1 = plot(bands and BPplotU ? BPplotU  : na, title = 'BP/SP', style=linebr, linewidth=1, color=CondCol)
p2 = plot(bands and SPplotU ? SPplotU  : na, title = 'SP/BP', style=linebr, linewidth=1, color=CondCol)
p3 = plot(bands and BPplotD ? BPplotD  : na, title = 'BP/SP', style=linebr, linewidth=1, color=CondCol)
p4 = plot(bands and SPplotD ? SPplotD  : na, title = 'SP/BP', style=linebr, linewidth=1, color=CondCol)
//Fills that color cloud based on Trend.
fill(p1, p2, color=green, transp=90, title='Cloud')
fill(p3, p4, color=red, transp=90, title='Cloud')
plot(bands and bpMavg ? bpMavg : na, title = 'BPavg', style=line, linewidth=1, color=green)
plot(bands and spMavg ? spMavg : na, title = 'SPavg', style=line, linewidth=1, color=red)
barcolor(colb?CondCol:na)
```
