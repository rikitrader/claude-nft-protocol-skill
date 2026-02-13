---
id: PUB;1562
title: Twiggs Money Flow_LB [SwetSwet]
author: swetswet
type: indicator
tags: []
boosts: 652
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1562
---

# Description
Twiggs Money Flow_LB [SwetSwet]

# Source Code
```pine
//
// @author LazyBear
// @credits http://www.incrediblecharts.com/indicators/twiggs_money_flow.php
// 
// If you use this code in its original/modified form, do drop me a note. 
//
study("Twiggs Money Flow [LazyBear]", shorttitle="TMF_LB_ss")
length = input( 21, "Period")
WiMA(src, length) => 
    MA_s=(src + nz(MA_s[1] * (length-1)))/length
    MA_s
    
hline(0)
tr_h=max(close[1],high)
tr_l=min(close[1],low)
tr_c=tr_h-tr_l
adv=volume*((close-tr_l)-(tr_h-close))/ iff(tr_c==0,9999999,tr_c)
wv=volume+(volume[1]*0)
wmV= WiMA(wv,length)
wmA= WiMA(adv,length)
tmf= iff(wmV==0,0,wmA/wmV)
tmff= iff(tmf>0.2499,tmf,0)
tmfm= iff(tmf<-0.2499,tmf,0)
plot(tmf, color=aqua, style=area)
plot(tmff,color=green, style=area)
plot(tmfm,color=red, style=area)


```
