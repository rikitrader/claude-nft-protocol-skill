---
id: PUB;1233
title: [LAVA] Renko Mod
author: Ni6HTH4wK
type: indicator
tags: []
boosts: 445
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1233
---

# Description
[LAVA] Renko Mod

# Source Code
```pine
// Tradingview.com Pinescript @author Ni6HTH4wK [LAVA] with assistance from @zmm20
// Original code by Richard Santos, [RS]Renko Mod
// ########## ☺♦♣♠♥☺ TIP YUR DEALER ☺♥♠♣♦☺ ###########
// [RS] https://www.tradingview.com/u/RicardoSantos/
// [LAVA]  19P7bkzqSAwSm6X7tXmRVkx6AuBXEUZioo
study("[LAVA] Renko Mod", overlay=true)

// Vars
n1 = input(1, title="Bricksize", minval=.01, type=float)
q1 = input(false, title="Type 1 (Def 2)")
q2 = input(false, title="Bar Colors")

// Sources
prclos = na(rclose[1])?round(close):nz(rclose[1])
propen = na(ropen[1])?round(open):nz(ropen[1])

// Renko (type 1 or type 2)
type = (q1?n1:n1*2)
rclose = close > prclos+type? prclos>propen? prclos+n1 : prclos+type :
    close < prclos-type? prclos<propen? prclos-n1 : prclos-type : prclos
ropen = rclose > prclos ? prclos>propen or q1? prclos : prclos+n1 : 
    rclose < prclos ? prclos<propen or q1? prclos : prclos-n1 : nz(ropen[1])

// Coloring
que = rclose > prclos ? 1 : rclose < prclos ? -1 : nz(que[1])
rc = que>0?green : que<0?red : na

// Plotting
plot(que>0?ropen:na, title="Renko Gurīn Open", style=circles, color=green, linewidth=2)
plot(que<0?ropen:na, title="Renko Aka Open", style=circles, color=red, linewidth=2)
plot(que>0?rclose:na, title="Renko Gurīn Close", style=cross, color=green, linewidth=3)
plot(que<0?rclose:na, title="Renko Aka Close", style=cross, color=red, linewidth=3)
barcolor(q2?rc:na)
```
