---
id: PUB;1942
title: SuperTrend Oscillator v3
author: j1O9SB
type: indicator
tags: []
boosts: 3020
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1942
---

# Description
SuperTrend Oscillator v3

# Source Code
```pine
//@version=2
study(title="SuperTrend Oscillator",shorttitle="STO",overlay=false)
//Inputs
spt_ures=input(false,title="Use Cutsom Resolution?")
spt_res=input(type=resolution,defval="M")
spt_lenw=input(200,title="Length Of Warning Range")
spt_len=input(14,title="SuperTrend Length")
spt_mult=input(1,title="SuperTrend Multiple")
spt_ubc=input(true,title="Use Barcolors?")
colup=green
coldn=red
//SuperTrend
spt_atr=atr(spt_len)
spt_nsb=hl2+spt_atr*spt_mult
spt_nlb=hl2-spt_atr*spt_mult
spt_lb=close[1]>spt_lb[1]?max(spt_nlb,spt_lb[1]):spt_nlb
spt_sb=close[1]<spt_sb[1]?min(spt_nsb,spt_sb[1]):spt_nsb
spt_tdur=close>spt_sb[1]?1:close<spt_lb[1]?-1:nz(spt_tdur[1],1)
spt_td=spt_ures?(security(tickerid,spt_res,spt_tdur)):spt_tdur
spt_lvlur=(close-(spt_td==1?spt_lb:spt_sb))
spt_lvl=spt_ures?(security(tickerid,spt_res,spt_lvlur)):spt_lvlur
//Components
spt_lvlup=spt_td==1?spt_lvl:na
spt_lvldn=spt_td==-1?spt_lvl:na
spt_tdup=(spt_td==1)and(spt_td[1]==-1)
spt_tddn=(spt_td==-1)and(spt_td[1]==1)
spt_tr=spt_ures?(security(tickerid,spt_res,tr)):tr
spt_matr=sma(abs(spt_lvl),200)
spt_cls=spt_ures?(security(tickerid,spt_res,close)):close
spt_lvlwup=(spt_lvlup<spt_matr)and(spt_cls<spt_cls[1])
spt_lvlwdn=(spt_lvldn>-spt_matr)and(spt_cls>spt_cls[1])
//Color
spt_col=spt_td==1?colup:coldn
spt_colbar=(spt_td==1)and(spt_lvlwup)?#A7D1AA:(spt_td==-1)and(spt_lvlwdn)?#D1A7AE:spt_td==1?colup:coldn
spt_colhst=spt_tdup?colup:spt_tddn?coldn:spt_lvlwdn?colup:spt_lvlwup?coldn:na
//Plot
p0=plot(0,color=spt_col,style=line,linewidth=1,transp=0,title="Midline")
p1=plot(spt_lvlup,color=colup,style=linebr,linewidth=1,transp=0,title="Uptrend Line")
p2=plot(spt_lvldn,color=coldn,style=linebr,linewidth=1,transp=0,title="Downtrend Line")
plot(spt_lvl,color=spt_colhst,style=histogram,linewidth=3,transp=0,title="Trend Change")
plot(spt_lvl,color=spt_colhst,style=circles,linewidth=2,transp=0,title="Trend Change")
fill(p0,p1,color=colup,transp=90)
fill(p0,p2,color=red,transp=90)
barcolor(spt_ubc?spt_colbar:na)
```
