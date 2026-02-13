---
id: PUB;16
title: Indicator: 8x MA with configurable lengths
author: LazyBear
type: indicator
tags: []
boosts: 2347
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_16
---

# Description
Indicator: 8x MA with configurable lengths

# Source Code
```pine
//
// @author LazyBear
// Generic 8x EMA plotter. Marks all EMA crossings. 
//
// Notes: I actually added an option to disable a specific MA line by specifying ZERO for it. 
//        This broke the Pinescript Engine. So, for now, please specify all MA values, though I have support
//        for disabling a line in the code. 
//
study(title="8x MA [LazyBear]", shorttitle="8xMA_LB", overlay=true)
src = close
ma1_color = #00ffff
ma2_color = #ff9800
ma3_color = #cc4125
ma4_color = #00ff00
ma5_color = #000080
ma6_color = #008080
ma7_color = #ff3366
ma8_color = #00cc66

use_ema=input(false, "Use EMA (default: SMA)?", type=bool)

ma1_p=input(8, title="MA1 Length", type=integer)
ma2_p=input(13, title="MA2 Length", type=integer)
ma3_p=input(41, title="MA3 Length", type=integer)
ma4_p=input(200, title="MA4 Length", type=integer)
ma5_p=input(243, title="MA5 Length", type=integer)
ma6_p=input(300, title="MA6 Length", type=integer)
ma7_p=input(500, title="MA7 Length", type=integer)
ma8_p=input(700, title="MA8 Length", type=integer)

ma1_valid = ma1_p > 0
ma2_valid = ma2_p > 0
ma3_valid = ma3_p > 0
ma4_valid = ma4_p > 0
ma5_valid = ma5_p > 0
ma6_valid = ma6_p > 0
ma7_valid = ma7_p > 0
ma8_valid = ma8_p > 0

ma(x,y) => use_ema ? ema(x,y) : sma(x,y)

ma1 = ma1_valid ? ma(src, ma1_p) : na
ma2 = ma2_valid ? ma(src, ma2_p) : na
ma3 = ma3_valid ? ma(src, ma3_p) : na
ma4 = ma4_valid ? ma(src, ma4_p) : na
ma5 = ma5_valid ? ma(src, ma5_p) : na
ma6 = ma6_valid ? ma(src, ma6_p) : na
ma7 = ma7_valid ? ma(src, ma7_p) : na
ma8 = ma8_valid ? ma(src, ma8_p) : na

ma1_cross= ma1_valid ? cross(ma1, ma2) or cross(ma1, ma3) or cross(ma1, ma4) or cross(ma1, ma5) or cross(ma1, ma6) or cross(ma1, ma7) or cross(ma1, ma8) : na
ma2_cross= ma2_valid ? cross(ma2, ma3) or cross(ma2, ma4) or cross(ma2, ma5) or cross(ma2, ma6) or cross(ma2, ma7) or cross(ma2, ma8) : na
ma3_cross= ma3_valid ? cross(ma3, ma4) or cross(ma3, ma5) or cross(ma3, ma6) or cross(ma3, ma7) or cross(ma3, ma8) : na
ma4_cross= ma4_valid ? cross(ma4, ma5) or cross(ma4, ma6) or cross(ma4, ma7) or cross(ma4, ma8) : na
ma5_cross= ma5_valid ? cross(ma5, ma6) or cross(ma5, ma7) or cross(ma5, ma8) : na
ma6_cross= ma6_valid ? cross(ma6, ma7) or cross(ma6, ma8) : na
ma7_cross= ma7_valid ? cross(ma7, ma8) : na

// Plot the EMAs
plot(ma1_valid ? ma1 : na, color = ma1_color, linewidth = 2)
plot(ma2_valid ? ma2 : na, color = ma2_color, linewidth = 2)
plot(ma3_valid ? ma3 : na, color = ma3_color, linewidth = 2)
plot(ma4_valid ? ma4 : na, color = ma4_color, linewidth = 2)
plot(ma5_valid ? ma5 : na, color = ma5_color, linewidth = 2)
plot(ma6_valid ? ma6 : na, color = ma6_color, linewidth = 2)
plot(ma7_valid ? ma7 : na, color = ma7_color, linewidth = 2)
plot(ma8_valid ? ma8 : na, color = ma8_color, linewidth = 2)

// Plot any crossings
plot(not na(ma1_cross) and ma1_cross ? ma1 : na, style = circles, linewidth = 4 , color = ma1_color)
plot(not na(ma2_cross) and ma2_cross ? ma2 : na, style = circles, linewidth = 4 , color = ma2_color)
plot(not na(ma3_cross) and ma3_cross ? ma3 : na, style = circles, linewidth = 4 , color = ma3_color)
plot(not na(ma4_cross) and ma4_cross ? ma4 : na, style = circles, linewidth = 4 , color = ma4_color)
plot(not na(ma5_cross) and ma5_cross ? ma5 : na, style = circles, linewidth = 4 , color = ma5_color)
plot(not na(ma6_cross) and ma6_cross ? ma6 : na, style = circles, linewidth = 4 , color = ma6_color)
plot(not na(ma7_cross) and ma7_cross ? ma7 : na, style = circles, linewidth = 4 , color = ma7_color)

```
