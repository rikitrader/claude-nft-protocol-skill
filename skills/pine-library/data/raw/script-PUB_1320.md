---
id: PUB;1320
title: Absolute Strength Index Oscillator [LazyBear]
author: LazyBear
type: indicator
tags: []
boosts: 3111
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1320
---

# Description
Absolute Strength Index Oscillator [LazyBear]

# Source Code
```pine
//
// @author LazyBear 
// 
// List of my public indicators: http://bit.ly/1LQaPK8 
// List of my app-store indicators: http://blog.tradingview.com/?p=970 
//
study("Absolute Strength Index Oscillator [LazyBear]", shorttitle="ABSSIO_LB")
sh=input(false, title="Show as Histo")
ebc=input(false, title="Enable Bar Colors")
lma=input(21, title="EMA Length")
ld=input(34, title="Signal Length")
osl=10 
calc_abssio( ) =>
    A=iff(close>close[1], nz(A[1])+(close/close[1])-1,nz(A[1]))
    M=iff(close==close[1], nz(M[1])+1.0/osl,nz(M[1]))
    D=iff(close<close[1], nz(D[1])+(close[1]/close)-1,nz(D[1]))
    iff (D+M/2==0, 1, 1-1/(1+(A+M/2)/(D+M/2)))

abssi=calc_abssio()
abssio = (abssi - ema(abssi,lma))
alp=2.0/(ld+1)
mt=alp*abssio+(1-alp)*nz(mt[1])
ut=alp*mt+(1-alp)*nz(ut[1])
s=((2-alp)*mt-ut)/(1-alp)
d=abssio-s
hline(0, title="ZeroLine")
plot(not sh ? abssio : na, color=(abssio > 0 ? abssio >= s ? green : orange : abssio <=s ? red :orange), title="ABSSIO", style=histogram, linewidth=2)
plot(not sh ? abssio : na, color=black, style=line,title="ABSSIO_Points", linewidth=2)
plot(not sh ? s : na, color=gray, title="MA")
plot(sh ? d : na, style=columns, color=d>0?green:red)
barcolor(ebc?(abssio > 0 ? abssio >= s ? lime : orange : abssio <=s ? red :orange):na)
```
