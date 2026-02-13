---
id: PUB;2935
title: Palladino/Booker Time Sessions
author: robbooker
type: indicator
tags: []
boosts: 518
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2935
---

# Description
Palladino/Booker Time Sessions

# Source Code
```pine
study("Palladino/Booker Time Sessions", overlay=true)

s = input(title="Session", type=session, defval="24x7")

int = tostring(interval)

timeinrange(res, sess) => time(res, sess) != 0
regular = blue
notrading = na
sessioncolor = timeinrange("1", s) ? regular : na
bgcolor(sessioncolor, transp=75)
```
