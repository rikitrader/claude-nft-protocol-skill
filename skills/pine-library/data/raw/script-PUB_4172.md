---
id: PUB;4172
title: HEIKIN ASHI COLOUR CHANGE ALERT
author: some1o1
type: indicator
tags: []
boosts: 2312
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_4172
---

# Description
HEIKIN ASHI COLOUR CHANGE ALERT

# Source Code
```pine
study("HEIKIN ASHI COLOUR CHANGE ALERT")

haclose = ((open + high + low + close)/4)
haopen = na(haopen[1]) ? (open + close)/2 : (haopen[1] + haclose[1]) / 2

UP = haclose > haclose [1]? 0:1
DOWN =  haclose <= haclose [1]? 1:0

plot(UP)
plot(DOWN)
```
