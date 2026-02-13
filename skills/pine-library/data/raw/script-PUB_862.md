---
id: PUB;862
title: Flex Renko Emulator
author: Zack_The_Lego
type: indicator
tags: []
boosts: 824
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_862
---

# Description
Flex Renko Emulator

# Source Code
```pine
//Zack_the_Lego
study("Flex Renko Emulator", overlay = true)
res = input(type=resolution, defval = "D", title = "Resolution of ATR")
xATR = atr(14)
//TF = x78tf ? "78" : "39"
BrickSize = security(tickerid,res, xATR)

Brick1    =  close >
        nz(Brick1[1]) + BrickSize ? nz(Brick1[1]) + BrickSize : close <
                    nz(Brick1[1]) - BrickSize ?
                        nz(Brick1[1]) - BrickSize
                            : nz(Brick1[1])
                            
Brick2 = Brick1 != Brick1[1] ? Brick1[1] : nz(Brick2[1])
colorer = Brick1 > Brick2 ? green:red
p1=plot(Brick1, color = colorer, linewidth= 4, title = "Renko")
p2=plot(Brick2, color = colorer, linewidth= 4, title = "Renko")
fill(p1,p2, color = purple, transp= 50)
```
