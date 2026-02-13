---
id: PUB;3185
title: True Day Session
author: P2_Trader
type: indicator
tags: []
boosts: 398
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_3185
---

# Description
True Day Session

# Source Code
```pine
//Created by user ChrisMoody 2-17-2014, modified by patrickpape1 8-22-2016
//Forex Session Templates Based on EST-New York Time Zone
//Special Thanks to TheLark AKA The Coding Genius for helping me with the "On - Off" CheckBoxes in the inputs tab

study(title="True Day Session",shorttitle="TDS", overlay=true)
timeinrange(res, sess) => time(res, sess) != 0

TD1 = gray

bgcolor(timeinrange("60","0000-0100") ? TD1 : na, transp=80, offset=0)
```
