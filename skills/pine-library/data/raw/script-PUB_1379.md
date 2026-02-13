---
id: PUB;1379
title: [RS]Renko Overlay V0
author: RicardoSantos
type: indicator
tags: []
boosts: 426
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1379
---

# Description
[RS]Renko Overlay V0

# Source Code
```pine
study(title='[RS]Renko Overlay V0', shorttitle='[RS]RO.V0', overlay=true)
tf = input('5')
mode = input('Traditional')
mode_value = input(0.0005, type=float)
showOverlay = input(true)
showBarColors = input(false)
showMA = input(false)
MA_length = input(12)

rt = renko(tickerid, 'close', mode, mode_value)

ro = security(rt, tf, open)
rc = security(rt, tf, close)

colorf = rc > ro ? #00ff80 : rc < ro ? #ff8000 : gray
plot(not showOverlay ? na : max(rc,ro), color=colorf, style=columns, transp=50)
plot(not showOverlay ? na : min(rc,ro), color=white, style=columns, transp=0)

ma = showMA ? sma(ro, MA_length) : na
plot(not showMA ? na : ma, color=black, linewidth=2)

barcolor(not showBarColors ? na : rc > ro ? lime : red)
```
