---
id: PUB;413
title: 3 projection Indicators - PBands, PO & PB
author: LazyBear
type: indicator
tags: []
boosts: 803
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_413
---

# Description
3 projection Indicators - PBands, PO & PB

# Source Code
```pine
//
// @author LazyBear
//
// If you use this code in its original/modified form, do drop me a note.
//
study("Projection Bands [LazyBear]", shorttitle="ProjectionBands_LB", overlay=true)
//length=input(14, title="Length")
length=14 // See below why this is a not an input()
sum_c=sum(cum(1),length)
psum_c=pow(sum_c,2)
sump_c=sum(pow(cum(1),2),length)
lsump_c=(length*sump_c)
denom=(lsump_c-psum_c)
rlh=((length*(sum(cum(1)*high,length)))-(sum_c*(sum(high,length))))/denom
rll=((length*(sum(cum(1)*low,length)))-(sum_c*(sum(low,length))))/denom

// Currently there is no way to do a loop. So, "length" is hardcoded to 14. 
// Bands
upb=max(high,
    max(high[1]+1*rlh,  
    max(high[2]+2*rlh,    
    max(high[3]+3*rlh,
    max(high[4]+4*rlh,
    max(high[5]+5*rlh,
    max(high[6]+6*rlh,
    max(high[7]+7*rlh,
    max(high[8]+8*rlh,
    max(high[9]+9*rlh,
    max(high[10]+10*rlh,
    max(high[11]+11*rlh,
    max(high[12]+12*rlh,
    high[13]+13*rlh)))))))))))))

//LowerProjectionBand
lpb=min(low,
    min(low[1]+1*rll,
    min(low[2]+2*rll,
    min(low[3]+3*rll,
    min(low[4]+4*rll,
    min(low[5]+5*rll,
    min(low[6]+6*rll,
    min(low[7]+7*rll,
    min(low[8]+8*rll,
    min(low[9]+9*rll,
    min(low[10]+10*rll,
    min(low[11]+11*rll,
    min(low[12]+12*rll,
    low[13]+13*rll)))))))))))))

ul=plot(upb, linewidth=2, color=teal)
ll=plot(lpb, linewidth=2, color=teal)
plot(avg(upb,lpb), linewidth=1, color=maroon)
fill(ul,ll,color=teal)
```
