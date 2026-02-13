---
id: PUB;2649
title: Stochastic Histogram
author: nboone
type: indicator
tags: []
boosts: 461
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2649
---

# Description
Stochastic Histogram

# Source Code
```pine
/////////////////////////////////////////////////////////////////////////////////////
// Last Edited: 5/19/16                                                            //    
// Created By: nboone                                                              //
//                                                                                 //
// Description:                                                                    //
// This is a basic Stochastic histogram that essentially shows when the indicator  //
// is either above or below the 50 level. Colors can be customized to your liking. //
// Length and smoothing factor can be adjusted as well. Defaults are 14 (Length)   //
// and 3 (Smoothing Factor).                                                       //                
/////////////////////////////////////////////////////////////////////////////////////
study(title="Stochastic Histogram", shorttitle="NB_StochHist")
length = input(14, minval=1)
smoothK = input(3, minval=1)

k = (sma(stoch(close, high, low, length), smoothK) - 50)
c = (k > 0) ? green : (k < 0) ? red : black

plot(k, style=histogram, color=c)
plot(k, color=black)
```
