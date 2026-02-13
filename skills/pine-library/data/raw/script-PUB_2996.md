---
id: PUB;2996
title: Triple Stochastic
author: Indicat
type: indicator
tags: []
boosts: 254
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2996
---

# Description
Triple Stochastic

# Source Code
```pine
study("Triple Stochastic",shorttitle="TS"),a=input(8,minval=2,title="Short Length")
b=input(21,minval=2,title="Medium Length"),c=input(55,minval=2,title="Long Length")
d=highest(a),e=lowest(a),f=highest(b),g=lowest(b),h=highest(c),i=lowest(c),j=hl2+(close-open)
k=0.5-(j-e)/(d-e),l=0.5-(j-g)/(f-g),m=0.5-(j-i)/(h-i),n=linreg(-k,a,0),o=linreg(-l,b,0),p=linreg(-m,c,0)
plot(p,color=change(linreg(n,(b-a),0))<=n?gray:blue,transp=90,linewidth=3,style=area,title="Long")
plot(o,color=red,transp=60,linewidth=2,title="Medium"),plot(n,color=blue,transp=40,title="Short")
hline(0.5),hline(-0.5),hline(0,color=silver,linestyle=dotted)
```
