---
id: PUB;576
title: Bitcoin Kill Zones
author: oscarvs
type: indicator
tags: []
boosts: 1465
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_576
---

# Description
Bitcoin Kill Zones

# Source Code
```pine
// Created by https://www.tradingview.com/u/oscarvs @ 01 October 2014 | @theoscarvs
// based on ChrisMoody scripts and http://blog.tradingview.com/?p=223
// https://gist.github.com/oscarvs/f05612579c9a174e8d5b

study(title="Bitcoin Kill Zones [oscarvs]",shorttitle="Bitcoin Kill Zones", overlay=true)
timeinrange(res, sess) => time(res, sess) != 0

doNYPre = input(defval=true, type = bool, title="NY Pre On")
doNYOpen = input(defval=true, type = bool, title="NY Kill Zone On")
doNYSession = input(defval=true, type = bool, title="NY Session On")

doAsiaPre = input(defval=false, type = bool, title="Asia Pre On")
doAsiaOpen = input(defval=false, type = bool, title="Asia Kill Zone On")
doAsiaSession = input(defval=false, type = bool, title="Asia Session On")

doLondonPre = input(defval=true, type = bool, title="London Pre On")
doLondonOpen = input(defval=true, type = bool, title="London Kill Zone On")
doLondonSession = input(defval=false, type = bool, title="London Session On")

bgcolor(doNYPre and timeinrange(period, "1130-1200") ? gray : na, transp=40)
bgcolor(doNYOpen and timeinrange(period, "1200-1210") ? red : na, transp=40)
bgcolor(doNYOpen and timeinrange(period, "1210-1250") ? red : na, transp=60)
bgcolor(doNYOpen and timeinrange(period, "1250-1300") ? red : na, transp=40)
bgcolor(doNYSession and timeinrange(period, "1300-2100") ? silver : na, transp=85)

bgcolor(doAsiaPre and timeinrange(period, "2230-2300") ? gray : na, transp=40)
bgcolor(doAsiaOpen and timeinrange(period, "2300-2310") ?  orange: na, transp=40)
bgcolor(doAsiaOpen and timeinrange(period, "2310-2350") ?  orange: na, transp=60)
bgcolor(doAsiaOpen and timeinrange(period, "2350-0000") ?  orange: na, transp=40)
bgcolor(doAsiaSession and timeinrange(period, "0000-0800") ? silver : na, transp=85)

bgcolor(doLondonPre and timeinrange(period, "0630-0700") ? gray : na, transp=40)
bgcolor(doLondonOpen and timeinrange(period, "0700-0710") ? green : na, transp=40)
bgcolor(doLondonOpen and timeinrange(period, "0710-0750") ? green : na, transp=60)
bgcolor(doLondonOpen and timeinrange(period, "0750-0800") ? green : na, transp=40)
bgcolor(doLondonSession and timeinrange(period, "0800-1600") ? silver : na, transp=85)
```
