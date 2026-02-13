---
id: PUB;qFY7x2V0PWQOQc2EPdMJfzwOwlgqGrMC
title: Price Action Candles v0.3 by JustUncleL
author: JustUncleL
type: indicator
tags: []
boosts: 3578
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_qFY7x2V0PWQOQc2EPdMJfzwOwlgqGrMC
---

# Description
Price Action Candles v0.3 by JustUncleL

# Source Code
```pine
//@version=2
//
// Name: Price Action Candlesticks v0.3 by JustUncleL
// By: JustUncleL
// Date: 16-Aug-2016
// Version: v0.3
//
// Description:
//   Identifies the candlestick patterns as used in
//   "Price Action Battle Station by theforexguy". All the identification 
//   of PA candles is dissabled by default.
//   The patterns identified are:
//   - Dark Cloud Cover (Yellow Highlight Bar): 
//       Large body bull green candle followed by large body
//       bear red candle that covers the upper bull candle and closes in the
//       lower 50% of bull body.
//   - Piecing Line (Aqua Highlight Bar): 
//       Large body bear red candle followed by large body
//       bull green candle that covers the lower bear candle and closes in the
//       upper 50% of bear body.
//   - Bearish Doji (aka Bearish) (Fuchsia Highlight above Bar): 
//       A large body Bull (green) candle followed by a small or no body candle 
//       with wicks top and bottom that are at least 60% of candle.
//   - Bullish Doji (aka Bullish Harami) (Fuchsia Highlight below Bar): 
//       A large body Bear (red) candle followed by a small or no body candle
//       with wicks top and bottom that are at least 60% of candle.
//   - Bullish Engulfing (Aqua Highlight Bar) (Aqua Highlight Bar): 
//       A bear red candle followed by a larger bull green candle
//       whose body covers the bear candle including the upper wick.
//   - Bearish Engulfing (Yellow Highlight Bar): 
//       A bull green candle followed by a larger bear red candle
//       whose body covers the bull candle including the lower wick.
//   - Bullish Outside Bar (Aqua Highlight Bar): 
//       A small inner red candle followed by a large outer green candle. 
//       The outer candle covers the whole inner candle (wick to wick)
//   - Bearish Outside Bar (Yellow Highlight Bar): 
//       A small inner green candle followed by a large outer red candle. 
//       The outer candle covers the whole inner candle (wick to wick)
//   - Inside Bar (Orange Highlight Bar): 
//       A large inner candle followed by a small outer candle. 
//       The inner candle covers the whole outer candle (wick to wick)
//   - Upper Shadow Pin Bar (aka bull rejection) (Aqua Highlight Bar): 
//       a small body bear (red) candle followed which has a large upper wick
//       and a small lower wick.
//   - Lower Shadow Pin Bar (aka bear rejection) (Yellow Highlight Bar): 
//       a small body bull (green) candle followed which has a large lower wick
//       and a small upper wick.
//   - Inverted Hammer (aka shooting star) (Yellow Highlight Bar): 
//       a small body bear (green) candle followed which has a large upper wick
//       and a small lower wick.
//   - Hammer (aka hanging man) (Aqua Highlight Bar) : 
//       a small body bull (red) candle followed which has a large lower wick
//       and a small upper wick.
//
//
// references:
//  - Inside/Outside Bars and Pin Barsome calculations based on
//        "CM_Price-Action-Patterns Price Bars That Work! by chrismoody"
//  - Other candles, although they all needed correcting, based on
//        "All Candlestick Pattern identifier by alona.gz"
//
// modifications:
//  0.3 Added optional Alertcondition so alarm can be created when any of the selected
//      Price Action Candles paterns are detected.
//      Modified Doji calculation to be more of a Harami candle, which means the previous
//      candle needs to be a large bull/bear candle, include selectable wick size and previous
//      candle body size.
//  0.2 Added Hammer and inverted hammer bars.
//      Added PA Bar Colouring as per "Price Action Battle Station by theforexguy"
//  0.1 Original Beta version.
//
study(title = "Price Action Candles v0.3 by JustUncleL", shorttitle="PACCDL v 0.3 by JustUncleL", overlay = true)
//

sdc = input(false,title="Show Dark Cloud Cover")
spl = input(false,title="Show Piecing Line")
sdj = input(false,title="Show Doji")
pctDw = input(60,minval=0,maxval=90,title="Doji, Min % of Range of Candle for Wicks")
pipMin= input(15,minval=1,title="Doji, Previous Candle Min Pip Body Size")
sble = input(false,title="Show Bullish Engulfing")
sbre = input(false,title="Show Bearish Engulfing")
sosb = input(false,title="Show Outside Bars")
sisb = input(false,title="Show Inside Bars")
supp = input(false,title="Show Up Reject Green Pin Bar")
sdnp = input(false,title="Show Down Reject Red Pin Bar")
shmr = input(false,title="Show Red Hammer")
sihmr = input(false,title="Show Green Inverted Hammer")
pctP = input(70, minval=1, maxval=99, title="PinBar/Hammer, Min % of Range of Candle for Long Wick")
sname=input(true,title="Show Price Action Bar Names")
cbar = input(false,title="Colour Price Action Bars")
setalm = input(false, title="Generate Alert for Selected PA Candles")

//
pip = syminfo.mintick
range = high - low

darkCloud=sdc and (close[1]>open[1] and (close[1]-open[1])>pipMin*pip and abs(close[1]-open[1])/range[1]>=0.7 and close<open and abs(close-open)/range>=0.7 and open>=close[1] and close>open[1] and close<((open[1]+close[1])/2))? 1: 0
plotshape(darkCloud and sname,title="Dark Cloud Cover",text='DarkCloud\nCover',color=red, style=shape.arrowdown,location=location.abovebar)

piecingLine=spl and (close[1]<open[1] and (open[1]-close[1])>pipMin*pip and abs(open[1]-close[1])/range[1]>=0.7 and close>open and abs(close-open)/range>=0.7 and open<=close[1] and close<open[1] and close>((open[1]+close[1])/2))? 1 : 0
plotshape(piecingLine and sname,title="Piercieng Line",text="Piercing\nLine",color=green, style=shape.arrowup,location=location.belowbar)

// Calculate Doji/Harami Candles
pctCDw = (pctDw/2) * 0.01
pctCDb = (100-pctDw) * 0.01
dojiBull=sdj and (open[1]>close[1] and (open[1]-close[1])>pipMin*pip and open[1] >= max(close,open) and close[1]<=min(close,open)) and (abs(close-open)/range<pctCDb and (high-max(close,open))>(pctCDw*range) and (min(close,open)-low)>(pctCDw*range))? 1 : 0
dojiBear=sdj and (open[1]<close[1] and (close[1]-open[1])>pipMin*pip and close[1] >= max(close,open) and open[1]<=min(close,open)) and (abs(close-open)/range<pctCDb and (high-max(close,open))>(pctCDw*range) and (min(close,open)-low)>(pctCDw*range))? 1 : 0
//
plotshape(dojiBear and sname?high:na,title="Bearish Doji",text='Bearish\nDoji',color=fuchsia, style=shape.arrowdown,location=location.abovebar)
plotshape(dojiBear and cbar?max(open,close):na,title="Bear Colour Doji",color=fuchsia, style=shape.circle,location=location.absolute,size=size.normal)
//
plotshape(dojiBull and sname?high:na,title="Bullish Doji",text='Bullish\nDoji',color=fuchsia, style=shape.arrowup,location=location.belowbar)
plotshape(dojiBull and cbar?max(open,close):na,title="Bull Colour Doji",color=fuchsia, style=shape.circle,location=location.absolute,size=size.normal)

//
bullishEngulf=sble and (close[1]<open[1] and close>open and close>=high[1] and open<=close[1]) ? 1 : 0
plotshape(bullishEngulf and sname,title="Bullish Engulfing",text='Bullish\nEngulfing',color=green, style=shape.arrowup,location=location.belowbar)

bearishEngulf=sbre and (close[1]>open[1] and close<open and close<=low[1] and open>=close[1]) ? 1 : 0
plotshape(bearishEngulf and sname,title="Bearish Engulfing",text='Bearish\nEngulfing',color=red, style=shape.arrowdown,location=location.abovebar)

//Inside Bars
insideBar = sisb and (high < high[1] and low > low[1]) ? 1 : 0
outsideBarBu= sosb and open[1]>close[1] and open<close and (high > high[1] and low < low[1]) ? 1 : 0
outsideBarBe= sosb and open[1]<close[1] and open>close and (high > high[1] and low < low[1]) ? 1 : 0

//Inside and Outside Bars
plotshape(insideBar and sname,title="Inside Bar",text="Inside\nBar",color=green, style=shape.arrowup,location=location.belowbar)
plotshape(outsideBarBe and sname,title="Bearish Outside Bar",text="Bearish\nOutsideBar",color=red, style=shape.arrowdown,location=location.abovebar)
plotshape(outsideBarBu and sname,title="Bullish Outside Bar",text="Bullish\nOutsideBar",color=green, style=shape.arrowup,location=location.belowbar)

//PBar Percentages
pctCp = pctP * .01

///PinBars Long Upper Shadow represent selling pressure
pBarUp = supp and (open>close and open < (high - (range * pctCp)) and close < (high - (range * pctCp))) ? 1 : 0
///PinBars with Long Lower Shadow represent buying pressure
pBarDn = sdnp and (open<close and open > (low + (range * pctCp)) and close > (low + (range * pctCp))) ? 1 : 0

plotshape(pBarUp and sname,title="Up Rejection Pin Bar",text='Up Reject\nPinBar',color=red, style=shape.arrowdown,location=location.abovebar)
plotshape(pBarDn and sname,title="Down Rejection Pin Bar",text='Down Reject\nPinBar',color=green, style=shape.arrowup,location=location.belowbar)

///PinBars Long Upper Shadow represent selling pressure
ihmr  = shmr and (open<close and open < (high - (range * pctCp)) and close < (high - (range * pctCp))) ? 1 : 0
///PinBars with Long Lower Shadow represent buying pressure
hmr = sihmr and (open>close and open > (low + (range * pctCp)) and close > (low + (range * pctCp))) ? 1 : 0

plotshape(ihmr and sname,title="Inverted Hammer",text='Inverted\nHammer',color=red, style=shape.arrowdown,location=location.abovebar)
plotshape(hmr and sname,title="Hammer",text='Hammer',color=green, style=shape.arrowup,location=location.belowbar)

bcolor = dojiBull or dojiBear? 1 : insideBar? 2 : (ihmr or pBarUp or bearishEngulf or darkCloud or outsideBarBe)? 3: (hmr or pBarDn or bullishEngulf or piecingLine or outsideBarBu)? 4 : 0
//
barcolor(cbar?bcolor==2?orange:bcolor==3?yellow:bcolor==4?aqua:na:na)

baralert = setalm and bcolor>0
alertcondition(baralert,title="PACCDL Alert",message="PACCDL Alert")

//
plotshape(na(baralert[1])?na:baralert[1], transp=0,style=shape.circle,location=location.bottom, offset=-1,title="Bar Alert Confirmed", 
  color=bcolor[1]==1?fuchsia : bcolor[1]==2?orange: bcolor[1]==3?yellow:bcolor[1]==4?aqua : na)

//EOF
```
