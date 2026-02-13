---
id: PUB;37
title: Found $13K Profit-Simple Strategy-Highlights Days Of The Week
author: ChrisMoody
type: indicator
tags: []
boosts: 2879
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_37
---

# Description
Found $13K Profit-Simple Strategy-Highlights Days Of The Week

# Source Code
```pine
//Created By ChrisMoody on 5-2-2014
//Colors Bars for Forex Monday-Friday
study("CM_DayOfWeek_Forex", overlay=true)
disMon = input(false, title="Highlight Monday?")
disTue = input(false, title="Highlight Tuesday?")
disWed = input(false, title="Highlight Wednesday?")
disThur = input(false, title="Highlight Thursday?")
disFri = input(false, title="Highlight Friday?")

isMon() => dayofweek == sunday and close ? 1 : 0
isTue() => dayofweek == monday and close ? 1 : 0
isWed() => dayofweek == tuesday and close ? 1 : 0
isThu() => dayofweek == wednesday and close ? 1 : 0
isFri() => dayofweek == thursday and close ? 1 : 0

barcolor(disMon and isMon() ? (isMon() ? yellow : na) : na)
barcolor(disTue and isTue() ? (isTue() ? fuchsia : na) : na)
barcolor(disWed and isWed() ? (isWed() ? gray : na) : na)
barcolor(disThur and isThu() ? (isThu() ? orange : na) : na)
barcolor(disFri and isFri() ? (isFri() ? aqua : na) : na)


```
