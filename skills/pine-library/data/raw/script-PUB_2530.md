---
id: PUB;2530
title: Forex Trading Sessions with Daylight Savings TimeV1 - Max Warren
author: UnknownUnicorn187266
type: indicator
tags: []
boosts: 361
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2530
---

# Description
Forex Trading Sessions with Daylight Savings TimeV1 - Max Warren

# Source Code
```pine
study(title="Sessions - Max Warren", shorttitle="Sessions - Max Warren", overlay=true)
timeinrange(res, sess) => time(res, sess) != 0
    
render = input(false,title="Slow but exact background (Refresh page)")
renderRes = render ? "1" : "5"
lines = input(true, title="Border")

//True = winter; False = summer
DST = input(true)

//Tokyo
tokyoSession = "2300-0800" // time does not change for tokyo
tokyoSLB = "2300-2310"
tokyoSRB = "0800-0810"
tokyoColor = red
tokyo = input(true)
tokyoLines = input(true, title="Lines")
bgcolor(tokyo and timeinrange(renderRes, tokyoSession) ? tokyoColor : na, transp=96, title="Tokyo Session")
bgcolor(tokyoLines and lines and timeinrange(renderRes, tokyoSLB) ? tokyoColor : na, transp=50, title="Tokyo Left Border")
bgcolor(tokyoLines and lines and timeinrange(renderRes, tokyoSRB) ? tokyoColor : na, transp=50, title="Tokyo Right Border")

//London
londonSession = DST == true ? "0800-1700" : "0700-1600" //summer
londonSLB = DST == true ? "0800-0810" : "0700-0710"
londonSRB = DST == true ? "1700-1710" : "1590-1600"
londonColor = blue
london = input(true)
londonLines = input(true, title="Lines")
bgcolor(london and timeinrange(renderRes, londonSession) ? londonColor : na, transp=96, title="London Session")
bgcolor(londonLines and lines and london and timeinrange(renderRes, londonSLB) ? londonColor : na, transp=50, title="London Left Border")
bgcolor(londonLines and lines and london and timeinrange(renderRes, londonSRB) ? londonColor : na, transp=50, title="London Right Border")

//New York
newyorkSession = DST == true ? "1300-2200" : "1200-2100" //summer
newyorkSLB = DST == true ? "1300-1310" : "1200-1210"
newyorkSRB = DST == true ? "2200-2210" : "2100-2110"
newyorkColor = green
newyork = input(true, title="New York")
newyorkLines = input(true, title="Lines")
bgcolor(newyork and timeinrange(renderRes, newyorkSession) ? newyorkColor : na, transp=96, title="New York Session")
bgcolor(newyorkLines and lines and newyork and timeinrange(renderRes, newyorkSLB) ? newyorkColor : na, transp=50, title="New York Left Border")
bgcolor(newyorkLines and lines and newyork and timeinrange(renderRes, newyorkSRB) ? newyorkColor : na, transp=50, title="New York Right Border")


sydneySession = DST == true ? "2100-0600" : "2200-0700" //summer
sydneySLB = DST == true ? "2100-2110" : "2210-2220"
sydneySRB = DST == true ? "0600-610" : "0690-0700"
sydneyColor = yellow
sydney = input(true)
sydneyLines = input(true, title="Lines")
bgcolor(sydney and timeinrange(renderRes, sydneySession) ? sydneyColor : na, transp=96, title="Sydney Session")
bgcolor(sydneyLines and lines and sydney and timeinrange(renderRes, sydneySLB) ? sydneyColor : na, transp=50, title="Sydney Left Border")
bgcolor(sydneyLines and lines and sydney and timeinrange(renderRes, sydneySRB) ? sydneyColor : na, transp=50, title="Sydney Right Border")


```
