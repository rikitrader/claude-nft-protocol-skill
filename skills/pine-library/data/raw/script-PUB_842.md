---
id: PUB;842
title: Least Squares Momentum
author: IldarAkhmetgaleev
type: indicator
tags: []
boosts: 255
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_842
---

# Description
Least Squares Momentum

# Source Code
```pine
study(title = "Least Squares Momentum", shorttitle="LSM", overlay=true)

length = input(title="Length", type=integer, defval=14)

source = close

mid = linreg(source, length, 0)
tail = linreg(source, length, length/2)
head = linreg(source, length, -length/2)

plot(head, color=#226622, title='head')
plot(mid, color=#333333, title='mid')
plot(tail, color=#881111, title='tail')
```
