---
id: PUB;513
title: Trade Session
author: HPotter
type: indicator
tags: []
boosts: 1029
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_513
---

# Description
Trade Session

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 03/09/2014
//  Marker of trade session
//  If you do not want painting all session, you should set -1 in the SessionStart 
//  and SessionEnd
////////////////////////////////////////////////////////////
study(title="Trade Session", overlay = true)
Session0Start = input(0)
Session0End = input(4)
Session1Start = input(5)
Session1End = input(7)
Session2Start = input(8)
Session2End = input(14)
Session3Start = input(15)
Session3End = input(19)
Session4Start = input(20)
Session4End = input(23)
BGColor0 = iff(hour >= Session0Start and hour <= Session0End, green, na)
BGColor1 = iff(hour >= Session1Start and hour <= Session1End, blue, na)
BGColor2 = iff(hour >= Session2Start and hour <= Session2End, red, na)
BGColor3 = iff(hour >= Session3Start and hour <= Session3End, gray, na)
BGColor4 = iff(hour >= Session4Start and hour <= Session4End, olive, na)
bgcolor(BGColor0, 80, 0)
bgcolor(BGColor1, 80, 0)
bgcolor(BGColor2, 80, 0)
bgcolor(BGColor3, 80, 0)
bgcolor(BGColor4, 80, 0)
```
