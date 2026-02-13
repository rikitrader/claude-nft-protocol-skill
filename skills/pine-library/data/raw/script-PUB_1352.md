---
id: PUB;1352
title: ZTLs Percentage-based Renko Emulator
author: Zack_The_Lego
type: indicator
tags: []
boosts: 434
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1352
---

# Description
ZTLs Percentage-based Renko Emulator

# Source Code
```pine
//Zack_the_Lego
study("ZTLs % Renko Emulator", overlay = true)
res = input(.001, minval = .0001, maxval = .30, title = "Resolution of ATR")

BrickSize = close[1] * res
 
Brick1    =  high >
        nz(Brick1[1],close) + BrickSize ? nz(Brick1[1],close) + BrickSize : low <
                    nz(Brick1[1],close) - BrickSize ?
                        nz(Brick1[1],close) - BrickSize
                            : nz(Brick1[1],close)
                            
Brick2 = Brick1 != Brick1[1] ? Brick1[1] : nz(Brick2[1],close)

projected = Brick1> Brick2 ? BrickSize + Brick1: Brick1 - BrickSize
projected2 = Brick1 > Brick2 ? Brick2 - BrickSize : Brick2 + BrickSize
colorer = Brick1 > Brick1[2]  ? aqua: Brick1 < Brick1[2] ? red : gray

plot(projected, color = yellow)
plot(projected2, color = yellow)
p1=plot(Brick1, color = colorer, linewidth= 4, title = "Renko")
p2=plot(Brick2, color = colorer, linewidth= 4, title = "Renko")
fill(p1,p2, color = purple, transp= 50)

```
