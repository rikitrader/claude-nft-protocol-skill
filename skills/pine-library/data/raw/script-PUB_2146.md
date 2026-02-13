---
id: PUB;2146
title: Williams Gator Oscillator
author: Petros
type: indicator
tags: []
boosts: 585
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2146
---

# Description
Williams Gator Oscillator

# Source Code
```pine
///////////////////////////////////
// The Gator Oscillator histogram above zero shows the absolute difference between blue and red lines of Alligator indicator,
// while histogram below zero shows the absolute difference between red and green lines.
//
// There are green and red bars on the Gator Oscillator histograms.
// A green bar appears when its value is higher than the value of the previous bar.
// A red bars appears when its value is lower than the value of the previous bar.
//
// Gator Oscillator helps to better visualize the upcoming changes in the trends: to know when Alligator sleeps, eats, fills out and is about to go to sleep. 
//
//////////////////////////////////

study("Williams Gator Oscillator", shorttitle="Gator")
smma(src, length) =>
    smma = na(smma[1]) ? sma(src, length) : (smma[1] * (length - 1) + src) / length
    smma
jawLength = input(13, "Jaw Length")
teethLength = input(8, "Teeth Length")
lipsLength = input(5, "Lips Length")
jaw = smma(hl2, jawLength)
teeth = smma(hl2, teethLength)
lips = smma(hl2, lipsLength)
jawOffset = offset (jaw, 8)
teethOffset = offset (teeth, 5)
lipsOffset = offset(lips,3)
up = abs (jawOffset - teethOffset)
down = abs (teethOffset - lipsOffset)
cClr1 = up > up [1]  ? green : red
cClr2 = down > down [1]  ? green : red
plot(up, style=histogram, linewidth=1, color=cClr1)
plot(-down, style=histogram, linewidth=1, color=cClr2)
```
