---
id: PUB;894
title: Volatility Switch Indicator [LazyBear]
author: LazyBear
type: indicator
tags: []
boosts: 1814
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_894
---

# Description
Volatility Switch Indicator [LazyBear]

# Source Code
```pine
//
// @author LazyBear 
// List of all my indicators: 
// https://docs.google.com/document/d/15AGCufJZ8CIUvwFJ9WIKns88gkWOKBCvByMEvm5MLo/edit?usp=sharing
//
study(title="Volatility Switch [LazyBear]", shorttitle="VOLSWITCH_LB")
dr= roc(close,1)/sma(close,2)
dummy=input(false, title="------- Choose lengths below ----"), il21=input(true, title="21"), il14=input(false, title="14")

vola21=stdev(dr, 21)
vswitch21=((vola21[1] <= vola21 ) + (vola21[2] <= vola21 ) +   (vola21[3] <= vola21 ) +   
		(vola21[4] <= vola21 ) +  (vola21[5] <= vola21 ) + (vola21[6] <= vola21 ) +   
		(vola21[7] <= vola21 ) +  (vola21[8] <= vola21 ) +  (vola21[9] <= vola21 ) +  
		(vola21[10] <= vola21 ) + (vola21[11] <= vola21 ) +  (vola21[12] <= vola21 ) +  
		(vola21[13] <= vola21 ) +  (vola21[14] <= vola21 ) +  (vola21[15] <= vola21 ) +  
		(vola21[16] <= vola21 ) +  (vola21[17] <= vola21 ) +  (vola21[18] <= vola21 ) +  
		(vola21[19] <= vola21 ) +  (vola21[20] <= vola21 ) + 1) / 21

vola14=stdev(dr, 14)
vswitch14=((vola14[1] <= vola14 ) + (vola14[2] <= vola14 ) +   (vola14[3] <= vola14 ) +   
		(vola14[4] <= vola14 ) +  (vola14[5] <= vola14 ) + (vola14[6] <= vola14 ) +   
		(vola14[7] <= vola14 ) +  (vola14[8] <= vola14 ) +  (vola14[9] <= vola14 ) +  
		(vola14[10] <= vola14 ) + (vola14[11] <= vola14 ) +  (vola14[12] <= vola14 ) +  
		(vola14[13] <= vola14 ) + 1) / 14 
 
hline(0.5, title="Median")
plot(il21?vswitch21:na, color=red, linewidth=2, title="VOLSWITCH_21")
plot(il14?vswitch14:na, color=green, linewidth=2, title="VOLSWITCH_14")

```
