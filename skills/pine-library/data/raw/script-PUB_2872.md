---
id: PUB;2872
title: Simple (Forex) Sessions - Asia,London, NY
author: PathToProfits
type: indicator
tags: []
boosts: 1845
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2872
---

# Description
Simple (Forex) Sessions - Asia,London, NY

# Source Code
```pine
//Created by user ChrisMoody 2-17-2014
//Modified by user PathToProfits 07-01-2016
//Forex Session Templates Based on EST-New York Time Zone

study(title="CM_Forex-Sessions-Highlight_V1",shorttitle="CM_forex_Sess_Highlight", overlay=true)
timeinrange(res, sess) => time(res, sess) != 0

//Change true to false = You have to turn on, won't show up by default
//****Always use lowercase letters

doNYOpen = input(defval=true, type = bool, title="NY Open On")
doNYSession = input(defval=true, type = bool, title="NY Session On")
doNYClose = input(defval=true, type = bool, title="NY Close On")

doAussieOpen = input(defval=true, type = bool, title="Aussie Open On")
doAussieSession = input(defval=true, type = bool, title="Aussie Session On")
doAussieClose = input(defval=true, type = bool, title="Aussie Close On")

doAsiaOpen = input(defval=true, type = bool, title="Asia Open On")
doAsiaSession = input(defval=true, type = bool, title="Asia Session On")
doAsiaClose = input(defval=true, type = bool, title="Asia Close On")

doEurOpen = input(defval=true, type = bool, title="Euro Open On")
doEurSession = input(defval=true, type = bool, title="Euro Session On")
doEurClose = input(defval=true, type = bool, title="Euro Close On")

//You can copy and paste these colors. white - silver - gray - maroon - red - purple - fuchsia - green - lime
//   olive - yellow - navy - blue - teal - aqua - orange 

nySessionStart = olive
nySession = olive
nySessionEnd = olive
asiaSessionStart = blue
asiaSession = blue
asiaSessionEnd = blue
europeSessionStart = red
europeSession = red
europeSessionEnd = red

//****Note ---- Use Military Times --- So 3:00PM = 1500

bgcolor(doAsiaSession and timeinrange(period, "1900-0400") ? asiaSession : na, transp=75)
bgcolor(doEurSession and timeinrange(period, "0330-0900") ? europeSession : na, transp=75)
bgcolor(doNYSession and timeinrange(period, "0930-1700") ? nySession : na, transp=75)


```
