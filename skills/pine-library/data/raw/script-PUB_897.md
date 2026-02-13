---
id: PUB;897
title: Trade Archer - On balance Volume Moving Averages - v1
author: tradearcher
type: indicator
tags: []
boosts: 740
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_897
---

# Description
Trade Archer - On balance Volume Moving Averages - v1

# Source Code
```pine
//Created By User Trade Archer (Kevin Johnson)
//Last Update 1/31/2015
//Added support for SMA, WMA, RMA, and VWMA.  Defaults to EMA
//Added plots of Highest and Lowest OBV x bars back
//Note: If you make some neat additions, let me know via PM.  Thanks & Enjoy
study(title="Trade Archer - On Balance Volume Moving Averages - v1", shorttitle="TA-OBVMAs-v1", overlay=false, precision=2)

//Collect input
source = input(3, type=integer, defval=3, minval=0, maxval=6, title="OBV Source: open=0 high=1 low=2 close=3 hl2=4 hlc3=5 ohlc4=6")
fast = input(9, minval=1, title="Fast MA")
medfast = input(19, minval=1, title="Medfast MA")
medslow = input(50, minval=1, title="Medslow MA")
slow = input(200, minval=1, title="Slow MA")
lo = input(10, title="lowest length")

usesma = input(false, title="SMA", defval=false, type=bool, defval=false)
useema = input(true, title="EMA (default)", defval=true, type=bool, defval=true)
usewma = input(false, title="WMA", defval=false, type=bool, defval=false)
userma = input(false, title="RMA", defval=false, type=bool, defval=false)
usevwma = input(false, title="VWMA", defval=false, type=bool, defval=false)

//Translate source
src = source == 0 ? open :
      source == 1 ? high :
      source == 2 ? low :
      source == 3 ? close :
      source == 4 ? hl2 :
      source == 5 ? hlc3 :
      source == 6 ? ohlc4 :
      close

//Get OBV
obv = cum(change(src) > 0 ? volume : change(src) < 0 ? -volume : 0*volume)

//Selects check MA type.  Defaults to EMA
fema = usesma ? sma( obv, fast) : useema ? ema( obv, fast) : usewma ? wma( obv, fast) : userma ? rma( obv, fast) :
       usevwma ? vwma( obv, fast) : ema( obv, fast)
mfema = usesma ? sma( obv, medfast) : useema ? ema( obv, medfast) : usewma ? wma( obv, medfast) : userma ? rma( obv, medfast) :
        usevwma ? vwma( obv, medfast) : ema( src, medfast)
msema = usesma ? sma( obv, medslow) : useema ? ema( obv, medslow) : usewma ? wma( obv, medslow) : userma ? rma( obv, medslow) :
        usevwma ? vwma( obv, medslow) : ema( obv, medslow)
sema = usesma ? sma( obv, slow) : useema ? ema( obv, slow) : usewma ? wma( obv, slow) : userma ? rma( obv, slow) :
       usevwma ? vwma( obv, slow) : ema( obv, slow)

//Plot Original OBV, Highest OBV and Lowest OBV x bars back
hp = plot( ceil(highest(obv,lo)), color=gray, linewidth=2, title="highest x bars")
lp = plot( floor(lowest(obv,lo)), color=gray, linewidth=2, title="lowest x bars")
pobv = plot(obv, color=black, linewidth=2, title="obv")

//Plot the MAs of OBV
pf = plot(fema, color=green, linewidth=1, title="fast avg")
pmf = plot(mfema, color=orange, linewidth=1, title="med fast avg")
pms = plot(msema, color=red, linewidth=2, title="med slow avg")
ps = plot(sema, color=maroon, linewidth=1, title="slow avg")


//fill between two emas
fill(pf, pmf, color=green, transp=45, title="short")
fill(pmf, pms, color=orange, transp=45, title="medium")
fill(pms, ps, color=red, transp=45, title="slow")


```
