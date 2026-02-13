---
id: PUB;1329
title: Forex Session Overlap
author: finn
type: indicator
tags: []
boosts: 691
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1329
---

# Description
Forex Session Overlap

# Source Code
```pine
// Created By: Finn
// Date: 2015-05-16 (initial publication)
// Description: Applies gray background coloring for each major active forex session,
//                  the more sessions active the lighter the background.
//              Adjusted coloring for low (Sydney, Tokyo) and high (Frankfurt, London, New York) liquidity
//              Market opening hours for Sydney, Tokyo, Frankfurt, London and 
//                  New York have been set to 08:00 - 17:00 local time and are converted
//                  to EST while taking daylight saving time into account across regions (REMEMBER: configure manually!).
//              Sessions can be turned on or off separately.
//              By default this indicator hides itself in larget timeframes (>30min by default).
//              Enabling session breaks or daily pivots helps distinguish between sessions.

study(title="Forex Session Overlap",shorttitle="Forex Session Overlap", overlay=true)
timeinrange(res, sess) => time(res, sess) != 0

maxDisplayInterval = input(defval=30,    type = integer, title="Hide above interval (minutes)", minval=1, maxval=240)
australiaDstOn     = input(defval=false, type = bool, title="Australia DST (summer time)")
europeDstOn    	   = input(defval=true,  type = bool, title="Europe DST (summer time)")
usaDstOn           = input(defval=true,  type = bool, title="U.S.A. DST (summer time)")

doSydney       = input(defval=true, type = bool, title="Sydney session")
doTokyo        = input(defval=true, type = bool, title="Tokyo session")
doFrankfurt    = input(defval=true, type = bool, title="Frankfurt session")
doLondon       = input(defval=true, type = bool, title="London session")
doNewYork      = input(defval=true, type = bool, title="New York session")

loadIndicator = (interval <= maxDisplayInterval)

lineTransparency = 50

marketPeriodColor       = #181818
marketPeriodColorLiquid = #303030

//Open/close times in local TimeZone DST Off:
//Syndey:    08:00 - 17:00 +10 GMT (+11 GMT @DST on, 04-10-2015 - 03-04-2016)
//Tokyo:     08:00 - 17:00  +9 GMT ( +9 GMT no DST!!)
//Frankfurt: 08:00 - 17:00  +1 GMT ( +2 GMT @DST on, 29-03-2015 - 25-10-2015)
//London:    08:00 - 17:00  +0 GMT ( +1 GMT @DST on, 29-03-2015 - 25-10-2015)
//New York:  08:00 - 17:00  -5 GMT ( -4 GMT @DST on, 08-03-2015 - 01-11-2015)

//**************************************************************************
//Convert all open times to EST (with and without DST differences)
//**Sydney to New York
//sydOpenDstOffNyDstOff = "1700" //-15h/+9h
//sydOpenDstOffNyDstOn  = "1800" //-14h/+10h
//sydOpenDstOnNyDstOff  = "1600" //-16h/+8h
//sydOpenDstOnNyDstOn   = "1700" //-15h/+9h
//**Tokyo (no DST) to New York
//tokOpenNyDstOff       = "18:00" //-14h/+10h
//tokOpenNyDstOn        = "19:00" //-13h/+11h
//**Central Europe to New York
//ffOpenDstOffNyDstOff  = "02:00" //-6h/+18h
//ffOpenDstOffNyDstOn   = "03:00" //-5h/+19h
//ffOpenDstOnNyDstOff   = "01:00" //-7h/+17h will not occur
//ffOpenDstOnNyDstOn    = "02:00" //-6h/+18h
//**London to New York
//lonOpenDstOffNyDstOff = "03:00" //-5h/+19h
//lonOpenDstOffNyDstOn  = "04:00" //-4h/+20h
//lonOpenDstOnNyDstOff  = "02:00" //-6h/+18h will not occur
//lonOpenDstOnNyDstOn   = "03:00" //-5h/+19h
//
// Close times are always 9 hours later as every market is open locally from 08:00 - 17:00
//
//**************************************************************************

//Determine which which times to use
audOpenDstOffNyDstOff = (not australiaDstOn and not usaDstOn)	//"1700" //-15h/+9h
audOpenDstOffNyDstOn  = (not australiaDstOn and usaDstOn)	    //"1800" //-14h/+10h
audOpenDstOnNyDstOff  = (australiaDstOn and not usaDstOn)	    //"1600" //-16h/+8h
audOpenDstOnNyDstOn   = (australiaDstOn and usaDstOn)		    //"1700" //-15h/+9h
jpyOpenNyDstOff       = (not usaDstOn)				            //"18:00" //-14h/+10h
jpyOpenNyDstOn        = usaDstOn				                //"19:00" //-13h/+11h
eurOpenDstOffNyDstOff = (not europeDstOn and not usaDstOn)	    //"02:00" //-6h/+18h
eurOpenDstOffNyDstOn  = (not europeDstOn and usaDstOn)	    	//"03:00" //-5h/+19h
eurOpenDstOnNyDstOff  = (europeDstOn and not usaDstOn)		    //"01:00" //-7h/+17h will not occur
eurOpenDstOnNyDstOn   = (europeDstOn and usaDstOn)		        //"02:00" //-6h/+18h

bgcolor(loadIndicator and doSydney  	and audOpenDstOffNyDstOff 	and timeinrange(period, "1700-0200")  ? marketPeriodColor       : na, transp=lineTransparency)
bgcolor(loadIndicator and doSydney  	and audOpenDstOffNyDstOn  	and timeinrange(period, "1800-0300")  ? marketPeriodColor       : na, transp=lineTransparency)
bgcolor(loadIndicator and doSydney  	and audOpenDstOnNyDstOff  	and timeinrange(period, "1600-0100")  ? marketPeriodColor       : na, transp=lineTransparency)
bgcolor(loadIndicator and doSydney  	and audOpenDstOnNyDstOn   	and timeinrange(period, "1700-0200")  ? marketPeriodColor       : na, transp=lineTransparency)
bgcolor(loadIndicator and doTokyo  	    and jpyOpenNyDstOff   		and timeinrange(period, "1800-0300")  ? marketPeriodColor       : na, transp=lineTransparency)
bgcolor(loadIndicator and doTokyo  	    and jpyOpenNyDstOn   		and timeinrange(period, "1900-0400")  ? marketPeriodColor       : na, transp=lineTransparency)
bgcolor(loadIndicator and doFrankfurt  	and eurOpenDstOffNyDstOff	and timeinrange(period, "0200-1100")  ? marketPeriodColorLiquid : na, transp=lineTransparency)
bgcolor(loadIndicator and doFrankfurt  	and eurOpenDstOffNyDstOn   	and timeinrange(period, "0300-1200")  ? marketPeriodColorLiquid : na, transp=lineTransparency)
bgcolor(loadIndicator and doFrankfurt  	and eurOpenDstOnNyDstOff  	and timeinrange(period, "0100-1000")  ? marketPeriodColorLiquid : na, transp=lineTransparency)
bgcolor(loadIndicator and doFrankfurt  	and eurOpenDstOnNyDstOn   	and timeinrange(period, "0200-1100")  ? marketPeriodColorLiquid : na, transp=lineTransparency)
bgcolor(loadIndicator and doLondon  	and eurOpenDstOffNyDstOff   and timeinrange(period, "0300-1200")  ? marketPeriodColorLiquid : na, transp=lineTransparency)
bgcolor(loadIndicator and doLondon  	and eurOpenDstOffNyDstOn   	and timeinrange(period, "0400-1300")  ? marketPeriodColorLiquid : na, transp=lineTransparency)
bgcolor(loadIndicator and doLondon  	and eurOpenDstOnNyDstOff   	and timeinrange(period, "0200-1100")  ? marketPeriodColorLiquid : na, transp=lineTransparency)
bgcolor(loadIndicator and doLondon  	and eurOpenDstOnNyDstOn   	and timeinrange(period, "0300-1200")  ? marketPeriodColorLiquid : na, transp=lineTransparency)
bgcolor(loadIndicator and doNewYork 	            				and timeinrange(period, "0800-1700")  ? marketPeriodColorLiquid : na, transp=lineTransparency)


```
