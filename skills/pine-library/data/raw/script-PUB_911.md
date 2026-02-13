---
id: PUB;911
title: UCS_Murrey's Math Oscillator
author: UDAY_C_Santhakumar
type: indicator
tags: []
boosts: 898
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_911
---

# Description
UCS_Murrey's Math Oscillator

# Source Code
```pine
// Created by UCSgears
// Modified the conceptual Murray Math Lines System overlay to an Oscillator
// Easier to add Alerts using an oscillator rather than an overlay
// Does provide some aesthetics, Will be improved as Time Progresses

study(title="UCS_Murrey's Math Oscillator", shorttitle="UCS_MMLO", overlay=false, precision = 2)
// Inputs
length = input(100, title = "Look back Length")
mult = input(0.125, title = "Mutiplier; 1/8 = 0.125; 1/4 = 0.25.....")
lines = input(true, title= "Show Murrey Math Fractals")
bc = input(true, title = "Show Bar Colors for Oversold and Overbought")
// Donchanin Channel
hi = highest(high, length)
lo = lowest(low, length)
range = hi - lo
multiplier = (range) * mult
midline = lo + multiplier * 4

oscillator = (close - midline)/(range/2)

scolor = oscillator > 0 and oscillator < mult*6 ? green : oscillator < 0 and oscillator > -mult*6 ? red : oscillator < -mult*6 ? blue : oscillator > mult*6 ? orange : na

plot (oscillator, color = scolor, title = "Murrey Math Oscillator", style = columns, transp = 60)
plot(0, title = "Zero Line", color = gray, linewidth = 4)

plot(lines == 1 ? mult*2 : na, title = "First Positive Quadrant", color = gray, linewidth = 1)
plot(lines == 1 ? mult*4 : na, title = "Second Positive Quadrant", color = gray, linewidth = 1)
p3 = plot(lines == 1 ? mult*6 : na, title = "Third Positive Quadrant", color = gray, linewidth = 1)
p4 = plot(lines == 1 ? mult*8 : na, title = "Fourth Positive Quadrant", color = gray, linewidth = 1)
plot(lines == 1 ? -mult*2 : na, title = "First Negative Quadrant", color = gray, linewidth = 1)
plot(lines == 1 ? -mult*4 : na, title = "Second Negative Quadrant", color = gray, linewidth = 1)
p2 = plot(lines == 1 ? -mult*6 : na, title = "Third Negative Quadrant", color = gray, linewidth = 1)
p1 = plot(lines == 1 ? -mult*8 : na, title = "Fourth Negative Quadrant", color = gray, linewidth = 1)

fill (p1,p2, color = orange)
fill (p3,p4, color = lime)

// Bar Color Oversold and Overbought
bcos = bc == 1 and oscillator > mult*6 ? orange : na
bcob = bc == 1 and oscillator < -mult*6 ? blue : na

barcolor (bcos)
barcolor (bcob)
```
