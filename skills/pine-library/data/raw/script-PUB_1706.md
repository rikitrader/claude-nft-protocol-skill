---
id: PUB;1706
title: EMA & SMA  with FRACTAL DEVIATION BANDS by @XeL_Arjona
author: xel_arjona
type: indicator
tags: []
boosts: 899
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1706
---

# Description
EMA & SMA  with FRACTAL DEVIATION BANDS by @XeL_Arjona

# Source Code
```pine
//	* EMA & SMA with FRACTAL DEVIATION BANDS.
//    Ver. 1.0.beta.25.08.2015
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
//      + "Morphic Numbers" (PHI & Plastic) Pine Script adaptation
//          from it's algebraic generation formulas by @XeL_Arjona
//      + "Fractal Deviation Bands" idea by @XeL_Arjona.
//
//         ALL NEW IDEAS OR MODIFICATIONS to these indicator(s) are
//      Welcome in favor to deploy a better and more accurate readings.
//      I will be very glad to be notified at Twitter or TradingVew
//      accounts at:   @XeL_Arjona
//
//      Any important addition to this work MUST REMAIN
//      PUBLIC by means of CreativeCommons CC & TradingView.
//      2015
//		
//////////////////////////////////////////////////////////////////
study("EMA & SMA  with FRACTAL DEVIATION BANDS by @XeL_Arjona", shorttitle="maFDB_XeL", overlay=true)
p = input(title="Lookback Periods:", defval=21)
src = input(title="Source", type=source, defval=close)
smn = input(false, title="Switch PHI Multiplier to PN:")
sema = input(true, title="Use EMA as Vortex:")
// Vortex
vortex = sema ? ema(src,p) : sma(src,p)
// N Root Function
nroot(index,number) =>
    cond_r = index == 0 or number == 0 or number < 0
    If_True = 0
    If_False = (exp((1/index) * log(number)))
    iff(cond_r, If_True, If_False)
// Bollinger Bands Function
BolTop(array,per,mult) =>
    std = stdev(array,per)*mult
    bbt = array + std
BolBot(array,per,mult) =>
    std = stdev(array,per)*mult
    bbb = array - std
//Morphic Number Constants for FRACTAL Multipliers.
_phi = (1+sqrt(5))/2  // Phi Number (Fibonacci Seq.)
_pn = (nroot(3,(108 + 12*sqrt(69))) + nroot(3,(108 - 12*sqrt(69))))/6  // Plastic Number (Podovan Seq.)
Fm = smn ? _pn : _phi
// Fractal Deviation Bands (Morphic Multiplier)
FDBvt = BolTop(vortex,p,Fm)   // Add As many layers
FDB1t = BolTop(FDBvt,p,Fm)    //  of fractal bands at
FDB2t = BolTop(FDB1t,p,Fm)    //  will.  Each band
FDB3t = BolTop(FDB2t,p,Fm)
FDBvb = BolBot(vortex,p,Fm)   //  is calculated having
FDB1b = BolBot(FDBvb,p,Fm)    //  as base the last one and
FDB2b = BolBot(FDB1b,p,Fm)    //  multiplied by morphic const.
FDB3b = BolBot(FDB2b,p,Fm)
// PLOT DIRECTIVES
CondCol = close > vortex ? green : red
//Center Avg Line
va = plot(vortex, color=CondCol, title='Vortex', style=line, linewidth=2, transp=0)
//Fractal Bands
t1 = plot(FDBvt, color=green, editable=false)
t2 = plot(FDB1t, color=green, editable=false)
t3 = plot(FDB2t, color=green, editable=false)
t4 = plot(FDB3t, color=green, editable=false)
b1 = plot(FDBvb, color=red, editable=false)
b2 = plot(FDB1b, color=red, editable=false)
b3 = plot(FDB2b, color=red, editable=false)
b4 = plot(FDB3b, color=red, editable=false)
// Cloud Background
fill(va, t1, color=green, transp=66, title='BullZ1')
fill(t1, t2, color=green, transp=75, title='BullZ2')
fill(t2, t3, color=green, transp=84, title='BullZ3')
fill(t3, t4, color=green, transp=93, title='BullZ4')
fill(va, b1, color=red, transp=66, title='BearZ1')
fill(b1, b2, color=red, transp=75, title='BearZ2')
fill(b2, b3, color=red, transp=84, title='BearZ3')
fill(b3, b4, color=red, transp=93, title='BearZ4')
```
