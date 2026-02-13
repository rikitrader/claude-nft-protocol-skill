---
id: PUB;1292
title: Fractals average breakout [FB]
author: frankie.baumann
type: indicator
tags: []
boosts: 1894
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1292
---

# Description
Fractals average breakout [FB]

# Source Code
```pine
//
// @author frankie.baumann
//

study("Fractals average breakout [FB]",shorttitle="FAB",overlay=true)

LookBack = input(5,minval=1,maxval=10)
ShMid = input(true, type=bool, title = "Show Midline?")
ShFL = input(true, type=bool, title = "Show Fractal lines?")

th = high[2]>high[1] and high[2]>high and high[2]>high[3] and high[2]>high[4] ? -1 : 0

bl = low[2]<low[1] and low[2]<low and low[2]<low[3] and low[2]<low[4] ? 1 : 0

tot = th + bl
pl = abs(tot)>=1 ? 1 : 0

// plotarrow(pl==1 ? tot : na,colorup=green,colordown=red,offset=-2,maxheight=10)

lowline = (valuewhen(tot==1, low[2], 0) + (LookBack>1 ? valuewhen(tot==1, low[2], 1) : 0)
    + (LookBack>2 ? valuewhen(tot==1, low[2], 2) : 0) + (LookBack>3 ? valuewhen(tot==1, low[2], 3) : 0)
    + (LookBack>4 ? valuewhen(tot==1, low[2], 4) : 0) + (LookBack>5 ? valuewhen(tot==1, low[2], 5) : 0)
    + (LookBack>6 ? valuewhen(tot==1, low[2], 6) : 0) + (LookBack>7 ? valuewhen(tot==1, low[2], 7) : 0)
    + (LookBack>8 ? valuewhen(tot==1, low[2], 8) : 0) + (LookBack>9 ? valuewhen(tot==1, low[2], 9) : 0)
    )/LookBack
plot(ShFL ? lowline : na, style=line, linewidth=2, color=green) //, offset=-2)

highline = (valuewhen(tot==-1, high[2], 0) + (LookBack>1 ? valuewhen(tot==-1, high[2], 1) : 0)
    + (LookBack>2 ? valuewhen(tot==-1, high[2], 2) : 0) + (LookBack>3 ? valuewhen(tot==-1, high[2], 3) : 0)
    + (LookBack>4 ? valuewhen(tot==-1, high[2], 4) : 0) + (LookBack>5 ? valuewhen(tot==-1, high[2], 5) : 0)
    + (LookBack>6 ? valuewhen(tot==-1, high[2], 6) : 0) + (LookBack>7 ? valuewhen(tot==-1, high[2], 7) : 0)
    + (LookBack>8 ? valuewhen(tot==-1, high[2], 8) : 0) + (LookBack>9 ? valuewhen(tot==-1, high[2], 9) : 0)
    )/LookBack
plot(ShFL ? highline : na, style=line, linewidth=2, color=red)

MidLine = (highline+lowline)/2
plot(ShMid ? MidLine : na, style=line, linewidth=2)
```
