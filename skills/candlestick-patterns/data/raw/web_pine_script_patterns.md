<!-- source: web research compilation -->
<!-- compiled: 2026-02-12 -->
<!-- sources: tradingview.com, github.com/shunjizhan, pinewizards.com, offline-pixel.github.io, zenandtheartoftrading.com, pineify.app -->

# Pine Script v6 -- Candlestick Pattern Detection Library

> Production-ready Pine Script v6 code examples for detecting the 20 most commonly used Japanese candlestick patterns. All code uses the `indicator()` function (Pine Script v6 syntax).

---

## Table of Contents

1. [Shared Utilities & Helper Functions](#1-shared-utilities--helper-functions)
2. [Single Candle Patterns](#2-single-candle-patterns)
3. [Double Candle Patterns](#3-double-candle-patterns)
4. [Triple Candle Patterns](#4-triple-candle-patterns)
5. [Complete Multi-Pattern Indicator](#5-complete-multi-pattern-indicator)
6. [Pattern Detection with Volume Confirmation](#6-pattern-detection-with-volume-confirmation)
7. [Pattern Detection with Trend Confirmation](#7-pattern-detection-with-trend-confirmation)

---

## 1. Shared Utilities & Helper Functions

These helper variables and functions are used across all pattern detection scripts. Include them at the top of any indicator that uses multiple patterns.

```pinescript
//@version=6
indicator("Candlestick Pattern Helpers", overlay=true)

// ============================================================================
// CANDLE COMPONENT CALCULATIONS
// ============================================================================

// Basic candle measurements
bodyHi    = math.max(close, open)
bodyLo    = math.min(close, open)
body      = bodyHi - bodyLo
midpoint  = body / 2 + bodyLo
upShadow  = high - bodyHi
dnShadow  = bodyLo - low
range_    = high - low  // underscore to avoid reserved word conflict

// Body classification
isWhiteBody  = close > open
isBlackBody  = close < open
isDoji       = body <= range_ * 0.05  // body is <= 5% of total range

// Body size relative to average
bodyAvg     = ta.ema(body, 14)
isLongBody  = body > bodyAvg
isSmallBody = body < bodyAvg

// Shadow classification (shadow > 5% of body to count)
shadowPct      = 5.0
hasUpShadow    = upShadow > shadowPct / 100 * body
hasDnShadow    = dnShadow > shadowPct / 100 * body
shadowEquals   = math.abs(upShadow - dnShadow) < range_ * 0.1

// Factor for shadow-to-body ratios
factor = 2.0

// ============================================================================
// TREND DETECTION
// ============================================================================

// SMA-based trend detection (configurable)
trendMethod = input.string("SMA50", "Trend Detection", options=["SMA50", "SMA50+200", "None"])
sma50  = ta.sma(close, 50)
sma200 = ta.sma(close, 200)

isDownTrend = switch trendMethod
    "SMA50"     => close < sma50
    "SMA50+200" => close < sma50 and sma50 < sma200
    => true

isUpTrend = switch trendMethod
    "SMA50"     => close > sma50
    "SMA50+200" => close > sma50 and sma50 > sma200
    => true

// ============================================================================
// VISUALIZATION HELPERS
// ============================================================================

labelOffsetLow  = low - ta.atr(30) * 0.6
labelOffsetHigh = high + ta.atr(30) * 0.6
colorBullish    = input.color(color.green, "Bullish Color")
colorBearish    = input.color(color.red, "Bearish Color")
```

---

## 2. Single Candle Patterns

### 2.1 Doji Detection

Detects standard Doji, Dragonfly Doji, Gravestone Doji, and Long-Legged Doji.

```pinescript
//@version=6
indicator("Doji Pattern Detector", overlay=true)

// Candle components
bodyHi   = math.max(close, open)
bodyLo   = math.min(close, open)
body     = bodyHi - bodyLo
range_   = high - low
upShadow = high - bodyHi
dnShadow = bodyLo - low

// Doji: body is <= 5% of the total range
dojiBodyPct = input.float(5.0, "Doji Body % Threshold", minval=1.0, maxval=15.0)
isDoji = range_ > 0 and body <= range_ * dojiBodyPct / 100

// Shadow equality check for standard Doji
shadowTolerance = 100.0  // percentage tolerance
shadowEquals = upShadow == dnShadow or
     (dnShadow > 0 and math.abs(upShadow - dnShadow) / dnShadow * 100 < shadowTolerance and
      upShadow > 0 and math.abs(dnShadow - upShadow) / upShadow * 100 < shadowTolerance)

// Standard Doji: equal shadows
standardDoji = isDoji and shadowEquals

// Dragonfly Doji: long lower shadow, no upper shadow
dragonflyDoji = isDoji and dnShadow > body * 3 and upShadow < body * 0.5

// Gravestone Doji: long upper shadow, no lower shadow
gravestoneDoji = isDoji and upShadow > body * 3 and dnShadow < body * 0.5

// Long-Legged Doji: very long shadows on both sides
longLegDoji = isDoji and upShadow > body * 3 and dnShadow > body * 3

// Visualization
plotshape(standardDoji and not dragonflyDoji and not gravestoneDoji and not longLegDoji,
     title="Doji", location=location.abovebar,
     color=color.new(color.yellow, 0), style=shape.diamond, size=size.small, text="Doji")

plotshape(dragonflyDoji, title="Dragonfly Doji", location=location.belowbar,
     color=color.new(color.green, 0), style=shape.triangleup, size=size.small, text="DF")

plotshape(gravestoneDoji, title="Gravestone Doji", location=location.abovebar,
     color=color.new(color.red, 0), style=shape.triangledown, size=size.small, text="GS")

plotshape(longLegDoji, title="Long-Legged Doji", location=location.abovebar,
     color=color.new(color.orange, 0), style=shape.diamond, size=size.small, text="LL")

// Alerts
alertcondition(dragonflyDoji, "Dragonfly Doji", "Dragonfly Doji detected - potential bullish reversal")
alertcondition(gravestoneDoji, "Gravestone Doji", "Gravestone Doji detected - potential bearish reversal")
```

---

### 2.2 Hammer & Inverted Hammer Detection

```pinescript
//@version=6
indicator("Hammer & Inverted Hammer Detector", overlay=true)

// Candle components
bodyHi   = math.max(close, open)
bodyLo   = math.min(close, open)
body     = bodyHi - bodyLo
range_   = high - low
upShadow = high - bodyHi
dnShadow = bodyLo - low
bodyAvg  = ta.ema(body, 14)

isSmallBody = body < bodyAvg
factor = input.float(2.0, "Shadow/Body Ratio", minval=1.5, maxval=4.0)

// Trend detection
sma50 = ta.sma(close, 50)
isDownTrend = close < sma50

// Hammer: small body at top, long lower shadow, minimal upper shadow
// Body must be in the upper 1/3 of the range
isHammer = isSmallBody and body > 0 and
     dnShadow >= factor * body and
     upShadow < body * 0.3 and
     bodyLo > low + range_ * 0.6 and
     isDownTrend

// Inverted Hammer: small body at bottom, long upper shadow, minimal lower shadow
// Body must be in the lower 1/3 of the range
isInvertedHammer = isSmallBody and body > 0 and
     upShadow >= factor * body and
     dnShadow < body * 0.3 and
     bodyHi < high - range_ * 0.6 and
     isDownTrend

// Visualization
plotshape(isHammer, title="Hammer", location=location.belowbar,
     color=color.new(color.green, 0), style=shape.triangleup, size=size.normal, text="Hammer")

plotshape(isInvertedHammer, title="Inverted Hammer", location=location.belowbar,
     color=color.new(color.lime, 0), style=shape.triangleup, size=size.small, text="Inv.Ham")

// Alerts
alertcondition(isHammer, "Hammer", "Hammer pattern detected - potential bullish reversal")
alertcondition(isInvertedHammer, "Inverted Hammer", "Inverted Hammer detected - potential bullish reversal")
```

---

### 2.3 Shooting Star & Hanging Man Detection

```pinescript
//@version=6
indicator("Shooting Star & Hanging Man Detector", overlay=true)

// Candle components
bodyHi   = math.max(close, open)
bodyLo   = math.min(close, open)
body     = bodyHi - bodyLo
range_   = high - low
upShadow = high - bodyHi
dnShadow = bodyLo - low
bodyAvg  = ta.ema(body, 14)

isSmallBody = body < bodyAvg
factor = input.float(2.0, "Shadow/Body Ratio", minval=1.5, maxval=4.0)

// Trend detection
sma50 = ta.sma(close, 50)
isUpTrend = close > sma50

// Shooting Star: small body at bottom, long upper shadow, minimal lower shadow
// Must appear in an uptrend
isShootingStar = isSmallBody and body > 0 and
     upShadow >= factor * body and
     dnShadow < body * 0.3 and
     bodyHi < high - range_ * 0.6 and
     isUpTrend

// Hanging Man: small body at top, long lower shadow, minimal upper shadow
// Must appear in an uptrend (same shape as Hammer but different context)
isHangingMan = isSmallBody and body > 0 and
     dnShadow >= factor * body and
     upShadow < body * 0.3 and
     bodyLo > low + range_ * 0.6 and
     isUpTrend

// Visualization
plotshape(isShootingStar, title="Shooting Star", location=location.abovebar,
     color=color.new(color.red, 0), style=shape.triangledown, size=size.normal, text="ShStar")

plotshape(isHangingMan, title="Hanging Man", location=location.abovebar,
     color=color.new(color.maroon, 0), style=shape.triangledown, size=size.small, text="HangM")

// Alerts
alertcondition(isShootingStar, "Shooting Star", "Shooting Star detected - potential bearish reversal")
alertcondition(isHangingMan, "Hanging Man", "Hanging Man detected - potential bearish reversal")
```

---

### 2.4 Marubozu Detection

```pinescript
//@version=6
indicator("Marubozu Detector", overlay=true)

// Candle components
bodyHi   = math.max(close, open)
bodyLo   = math.min(close, open)
body     = bodyHi - bodyLo
range_   = high - low
upShadow = high - bodyHi
dnShadow = bodyLo - low
bodyAvg  = ta.ema(body, 14)

isLongBody = body > bodyAvg

// Marubozu threshold: shadows must be <= 1% of body
shadowThreshold = input.float(1.0, "Max Shadow % of Body", minval=0.0, maxval=5.0)

// Bullish Marubozu: long green body, no shadows (or negligible)
isBullishMarubozu = isLongBody and close > open and
     upShadow <= body * shadowThreshold / 100 and
     dnShadow <= body * shadowThreshold / 100

// Bearish Marubozu: long red body, no shadows
isBearishMarubozu = isLongBody and close < open and
     upShadow <= body * shadowThreshold / 100 and
     dnShadow <= body * shadowThreshold / 100

// Opening Marubozu variants (one shadow present)
isBullishOpenMarubozu = isLongBody and close > open and
     dnShadow <= body * shadowThreshold / 100 and upShadow > body * shadowThreshold / 100

isBearishOpenMarubozu = isLongBody and close < open and
     upShadow <= body * shadowThreshold / 100 and dnShadow > body * shadowThreshold / 100

// Visualization
plotshape(isBullishMarubozu, title="Bullish Marubozu", location=location.belowbar,
     color=color.new(color.green, 0), style=shape.arrowup, size=size.normal, text="BullM")

plotshape(isBearishMarubozu, title="Bearish Marubozu", location=location.abovebar,
     color=color.new(color.red, 0), style=shape.arrowdown, size=size.normal, text="BearM")

// Alerts
alertcondition(isBullishMarubozu, "Bullish Marubozu", "Bullish Marubozu - strong buyer control")
alertcondition(isBearishMarubozu, "Bearish Marubozu", "Bearish Marubozu - strong seller control")
```

---

## 3. Double Candle Patterns

### 3.1 Bullish & Bearish Engulfing

```pinescript
//@version=6
indicator("Engulfing Pattern Detector", overlay=true)

// Candle components
bodyHi   = math.max(close, open)
bodyLo   = math.min(close, open)
body     = bodyHi - bodyLo
bodyAvg  = ta.ema(body, 14)

isWhiteBody = close > open
isBlackBody = close < open
isLongBody  = body > bodyAvg

// Previous candle components
prevBodyHi  = math.max(close[1], open[1])
prevBodyLo  = math.min(close[1], open[1])
prevBody    = prevBodyHi - prevBodyLo
prevIsWhite = close[1] > open[1]
prevIsBlack = close[1] < open[1]

// Trend detection
sma50 = ta.sma(close, 50)
isDownTrend = close < sma50
isUpTrend   = close > sma50

// Bullish Engulfing: current white body engulfs previous black body
// Must occur in a downtrend
isBullishEngulfing = isDownTrend and
     isWhiteBody and isLongBody and
     prevIsBlack and
     bodyHi > prevBodyHi and bodyLo < prevBodyLo

// Bearish Engulfing: current black body engulfs previous white body
// Must occur in an uptrend
isBearishEngulfing = isUpTrend and
     isBlackBody and isLongBody and
     prevIsWhite and
     bodyHi > prevBodyHi and bodyLo < prevBodyLo

// Visualization
plotshape(isBullishEngulfing, title="Bullish Engulfing", location=location.belowbar,
     color=color.new(color.green, 0), style=shape.triangleup, size=size.normal, text="BullEng")

plotshape(isBearishEngulfing, title="Bearish Engulfing", location=location.abovebar,
     color=color.new(color.red, 0), style=shape.triangledown, size=size.normal, text="BearEng")

// Alerts
alertcondition(isBullishEngulfing, "Bullish Engulfing", "Bullish Engulfing detected!")
alertcondition(isBearishEngulfing, "Bearish Engulfing", "Bearish Engulfing detected!")
```

---

### 3.2 Bullish & Bearish Harami

```pinescript
//@version=6
indicator("Harami Pattern Detector", overlay=true)

// Candle components
bodyHi = math.max(close, open)
bodyLo = math.min(close, open)
body   = bodyHi - bodyLo
range_ = high - low

isWhiteBody = close > open
isBlackBody = close < open

// Previous candle
prevBodyHi = math.max(close[1], open[1])
prevBodyLo = math.min(close[1], open[1])
prevBody   = prevBodyHi - prevBodyLo
bodyAvg    = ta.ema(prevBody, 14)

prevIsLongBody = prevBody > bodyAvg
isSmallBody    = body < bodyAvg

// Trend detection
sma50 = ta.sma(close, 50)
isDownTrend = close[1] < sma50
isUpTrend   = close[1] > sma50

// Doji check for Harami Cross variant
isDoji = range_ > 0 and body <= range_ * 0.05

// Bullish Harami: large bearish candle followed by small bullish candle inside it
isBullishHarami = isDownTrend and
     close[1] < open[1] and prevIsLongBody and
     isWhiteBody and isSmallBody and
     bodyHi < prevBodyHi and bodyLo > prevBodyLo

// Bearish Harami: large bullish candle followed by small bearish candle inside it
isBearishHarami = isUpTrend and
     close[1] > open[1] and prevIsLongBody and
     isBlackBody and isSmallBody and
     bodyHi < prevBodyHi and bodyLo > prevBodyLo

// Harami Cross variants (second candle is a Doji)
isBullishHaramiCross = isDownTrend and
     close[1] < open[1] and prevIsLongBody and
     isDoji and
     bodyHi < prevBodyHi and bodyLo > prevBodyLo

isBearishHaramiCross = isUpTrend and
     close[1] > open[1] and prevIsLongBody and
     isDoji and
     bodyHi < prevBodyHi and bodyLo > prevBodyLo

// Visualization
plotshape(isBullishHarami and not isBullishHaramiCross, title="Bullish Harami",
     location=location.belowbar, color=color.new(color.green, 0),
     style=shape.triangleup, size=size.small, text="BHar")

plotshape(isBearishHarami and not isBearishHaramiCross, title="Bearish Harami",
     location=location.abovebar, color=color.new(color.red, 0),
     style=shape.triangledown, size=size.small, text="BrHar")

plotshape(isBullishHaramiCross, title="Bullish Harami Cross",
     location=location.belowbar, color=color.new(color.lime, 0),
     style=shape.diamond, size=size.small, text="BHarX")

plotshape(isBearishHaramiCross, title="Bearish Harami Cross",
     location=location.abovebar, color=color.new(color.fuchsia, 0),
     style=shape.diamond, size=size.small, text="BrHarX")

// Alerts
alertcondition(isBullishHarami, "Bullish Harami", "Bullish Harami detected")
alertcondition(isBearishHarami, "Bearish Harami", "Bearish Harami detected")
alertcondition(isBullishHaramiCross, "Bullish Harami Cross", "Bullish Harami Cross detected")
alertcondition(isBearishHaramiCross, "Bearish Harami Cross", "Bearish Harami Cross detected")
```

---

### 3.3 Piercing Line & Dark Cloud Cover

```pinescript
//@version=6
indicator("Piercing & Dark Cloud Detector", overlay=true)

// Candle components
bodyHi = math.max(close, open)
bodyLo = math.min(close, open)
body   = bodyHi - bodyLo
bodyAvg = ta.ema(body, 14)

isLongBody = body > bodyAvg

// Previous candle components
prevBodyHi = math.max(close[1], open[1])
prevBodyLo = math.min(close[1], open[1])
prevBody   = prevBodyHi - prevBodyLo
prevMid    = prevBody / 2 + prevBodyLo

// Trend detection
sma50 = ta.sma(close, 50)
isDownTrend = close[1] < sma50
isUpTrend   = close[1] > sma50

// Piercing Line: bearish candle followed by bullish candle that:
//   - Opens below the prior low
//   - Closes above the midpoint of the prior body
isPiercingLine = isDownTrend and
     close[1] < open[1] and prevBody > bodyAvg and     // first: long bearish
     close > open and isLongBody and                     // second: long bullish
     open < low[1] and                                   // opens below prior low
     close > prevMid and close < prevBodyHi               // closes above midpoint but below prior open

// Dark Cloud Cover: bullish candle followed by bearish candle that:
//   - Opens above the prior high
//   - Closes below the midpoint of the prior body
isDarkCloudCover = isUpTrend and
     close[1] > open[1] and prevBody > bodyAvg and      // first: long bullish
     close < open and isLongBody and                      // second: long bearish
     open > high[1] and                                   // opens above prior high
     close < prevMid and close > prevBodyLo               // closes below midpoint but above prior close

// Visualization
plotshape(isPiercingLine, title="Piercing Line", location=location.belowbar,
     color=color.new(color.green, 0), style=shape.arrowup, size=size.normal, text="Pierce")

plotshape(isDarkCloudCover, title="Dark Cloud Cover", location=location.abovebar,
     color=color.new(color.red, 0), style=shape.arrowdown, size=size.normal, text="DCC")

// Alerts
alertcondition(isPiercingLine, "Piercing Line", "Piercing Line - bullish reversal signal")
alertcondition(isDarkCloudCover, "Dark Cloud Cover", "Dark Cloud Cover - bearish reversal signal")
```

---

### 3.4 Tweezer Top & Bottom

```pinescript
//@version=6
indicator("Tweezer Detector", overlay=true)

// Candle components
bodyHi = math.max(close, open)
bodyLo = math.min(close, open)

// Tolerance for matching highs/lows (as % of ATR)
atr14 = ta.atr(14)
tolerance = atr14 * 0.01  // 1% of ATR

// Trend detection
sma50 = ta.sma(close, 50)
isDownTrend = close[1] < sma50
isUpTrend   = close[1] > sma50

// Tweezer Bottom: two candles with matching lows
// First bearish, second bullish (classic form)
isTweezerBottom = isDownTrend and
     close[1] < open[1] and                             // first is bearish
     close > open and                                    // second is bullish
     math.abs(low - low[1]) <= tolerance                  // matching lows

// Tweezer Top: two candles with matching highs
// First bullish, second bearish (classic form)
isTweezerTop = isUpTrend and
     close[1] > open[1] and                             // first is bullish
     close < open and                                    // second is bearish
     math.abs(high - high[1]) <= tolerance                // matching highs

// Visualization
plotshape(isTweezerBottom, title="Tweezer Bottom", location=location.belowbar,
     color=color.new(color.green, 0), style=shape.triangleup, size=size.small, text="TwzBot")

plotshape(isTweezerTop, title="Tweezer Top", location=location.abovebar,
     color=color.new(color.red, 0), style=shape.triangledown, size=size.small, text="TwzTop")

// Alerts
alertcondition(isTweezerBottom, "Tweezer Bottom", "Tweezer Bottom - bullish reversal")
alertcondition(isTweezerTop, "Tweezer Top", "Tweezer Top - bearish reversal")
```

---

## 4. Triple Candle Patterns

### 4.1 Morning Star & Evening Star

```pinescript
//@version=6
indicator("Morning & Evening Star Detector", overlay=true)

// Candle components
bodyHi   = math.max(close, open)
bodyLo   = math.min(close, open)
body     = bodyHi - bodyLo
range_   = high - low
bodyAvg  = ta.ema(body, 14)

isLongBody  = body > bodyAvg
isSmallBody = body < bodyAvg
isWhiteBody = close > open
isBlackBody = close < open

// Doji check
isDoji = range_ > 0 and body <= range_ * 0.05

// Previous candle measurements
prevBodyHi  = math.max(close[1], open[1])
prevBodyLo  = math.min(close[1], open[1])
prevBody    = prevBodyHi - prevBodyLo

// Two-candles-ago measurements
bodyHi2  = math.max(close[2], open[2])
bodyLo2  = math.min(close[2], open[2])
body2    = bodyHi2 - bodyLo2
bodyMid2 = body2 / 2 + bodyLo2

// Trend detection
sma50 = ta.sma(close, 50)
isDownTrend = close[2] < sma50
isUpTrend   = close[2] > sma50

// Morning Star: long bearish -> small body (gap down) -> long bullish (closes above midpoint of 1st)
isMorningStar = isDownTrend and
     close[2] < open[2] and body2 > bodyAvg and             // 1st: long bearish
     isSmallBody[1] and                                       // 2nd: small body (star)
     prevBodyHi < bodyLo2 and                                 // gap down between 1st and 2nd
     isWhiteBody and isLongBody and                           // 3rd: long bullish
     bodyHi >= bodyMid2 and bodyHi < bodyHi2                  // closes above midpoint of 1st

// Morning Doji Star variant
isMorningDojiStar = isDownTrend and
     close[2] < open[2] and body2 > bodyAvg and
     isDoji[1] and
     prevBodyHi < bodyLo2 and
     isWhiteBody and isLongBody and
     bodyHi >= bodyMid2 and bodyHi < bodyHi2 and
     prevBodyHi < bodyLo

// Evening Star: long bullish -> small body (gap up) -> long bearish (closes below midpoint of 1st)
isEveningStar = isUpTrend and
     close[2] > open[2] and body2 > bodyAvg and             // 1st: long bullish
     isSmallBody[1] and                                       // 2nd: small body (star)
     prevBodyLo > bodyHi2 and                                 // gap up between 1st and 2nd
     isBlackBody and isLongBody and                           // 3rd: long bearish
     bodyLo <= bodyMid2 and bodyLo > bodyLo2                  // closes below midpoint of 1st

// Evening Doji Star variant
isEveningDojiStar = isUpTrend and
     close[2] > open[2] and body2 > bodyAvg and
     isDoji[1] and
     prevBodyLo > bodyHi2 and
     isBlackBody and isLongBody and
     bodyLo <= bodyMid2 and bodyLo > bodyLo2

// Visualization
plotshape(isMorningStar and not isMorningDojiStar, title="Morning Star",
     location=location.belowbar, color=color.new(color.green, 0),
     style=shape.arrowup, size=size.normal, text="MornStar")

plotshape(isMorningDojiStar, title="Morning Doji Star",
     location=location.belowbar, color=color.new(color.lime, 0),
     style=shape.arrowup, size=size.normal, text="MDStar")

plotshape(isEveningStar and not isEveningDojiStar, title="Evening Star",
     location=location.abovebar, color=color.new(color.red, 0),
     style=shape.arrowdown, size=size.normal, text="EveStar")

plotshape(isEveningDojiStar, title="Evening Doji Star",
     location=location.abovebar, color=color.new(color.maroon, 0),
     style=shape.arrowdown, size=size.normal, text="EDStar")

// Highlight pattern candles
mornStarAny = isMorningStar or isMorningDojiStar
eveStarAny  = isEveningStar or isEveningDojiStar

bgcolor(ta.highest(mornStarAny ? 1 : 0, 3) != 0 ? color.new(color.green, 90) : na, offset=-2)
bgcolor(ta.highest(eveStarAny ? 1 : 0, 3) != 0 ? color.new(color.red, 90) : na, offset=-2)

// Alerts
alertcondition(isMorningStar or isMorningDojiStar, "Morning Star", "Morning Star - bullish reversal")
alertcondition(isEveningStar or isEveningDojiStar, "Evening Star", "Evening Star - bearish reversal")
```

---

### 4.2 Three White Soldiers & Three Black Crows

```pinescript
//@version=6
indicator("Three Soldiers & Crows Detector", overlay=true)

// Candle components
bodyHi   = math.max(close, open)
bodyLo   = math.min(close, open)
body     = bodyHi - bodyLo
range_   = high - low
upShadow = high - bodyHi
bodyAvg  = ta.ema(body, 14)

isLongBody  = body > bodyAvg
isWhiteBody = close > open
isBlackBody = close < open

// Shadow threshold: upper shadow should be small (< 5% of range)
shadowPct = 5.0
hasSmallUpShadow    = range_ * shadowPct / 100 > upShadow
hasSmallDnShadow    = range_ * shadowPct / 100 > (bodyLo - low)

// Three White Soldiers:
// - Three consecutive long white bodies
// - Each opens within the prior body and closes higher
// - Minimal upper shadows
isThreeWhiteSoldiers = false
if isLongBody and isLongBody[1] and isLongBody[2]
    if isWhiteBody and isWhiteBody[1] and isWhiteBody[2]
        isThreeWhiteSoldiers := close > close[1] and close[1] > close[2] and
             open < close[1] and open > open[1] and
             open[1] < close[2] and open[1] > open[2] and
             hasSmallUpShadow and hasSmallUpShadow[1] and hasSmallUpShadow[2]

// Three Black Crows:
// - Three consecutive long black bodies
// - Each opens within the prior body and closes lower
// - Minimal lower shadows
isThreeBlackCrows = false
if isLongBody and isLongBody[1] and isLongBody[2]
    if isBlackBody and isBlackBody[1] and isBlackBody[2]
        isThreeBlackCrows := close < close[1] and close[1] < close[2] and
             open > close[1] and open < open[1] and
             open[1] > close[2] and open[1] < open[2] and
             hasSmallDnShadow and hasSmallDnShadow[1] and hasSmallDnShadow[2]

// Visualization
labelOffsetLow  = low - ta.atr(30) * 0.6
labelOffsetHigh = high + ta.atr(30) * 0.6

if isThreeWhiteSoldiers
    label.new(bar_index, labelOffsetLow, text="3WS",
         style=label.style_label_up, color=color.green, textcolor=color.white,
         tooltip="Three White Soldiers - Strong bullish reversal/continuation")

if isThreeBlackCrows
    label.new(bar_index, labelOffsetHigh, text="3BC",
         style=label.style_label_down, color=color.red, textcolor=color.white,
         tooltip="Three Black Crows - Strong bearish reversal/continuation")

// Background highlight across the 3 candles
bgcolor(ta.highest(isThreeWhiteSoldiers ? 1 : 0, 3) != 0 ? color.new(color.green, 90) : na, offset=-2)
bgcolor(ta.highest(isThreeBlackCrows ? 1 : 0, 3) != 0 ? color.new(color.red, 90) : na, offset=-2)

// Alerts
alertcondition(isThreeWhiteSoldiers, "Three White Soldiers", "Three White Soldiers detected - bullish")
alertcondition(isThreeBlackCrows, "Three Black Crows", "Three Black Crows detected - bearish")
```

---

### 4.3 Three Inside Up & Three Inside Down

```pinescript
//@version=6
indicator("Three Inside Up/Down Detector", overlay=true)

// Candle components
bodyHi  = math.max(close, open)
bodyLo  = math.min(close, open)
body    = bodyHi - bodyLo
bodyAvg = ta.ema(body, 14)

isWhiteBody = close > open
isBlackBody = close < open
isLongBody  = body > bodyAvg
isSmallBody = body < bodyAvg

// Previous candle components
prevBodyHi = math.max(close[1], open[1])
prevBodyLo = math.min(close[1], open[1])

// Two-candles-ago components
bodyHi2 = math.max(close[2], open[2])
bodyLo2 = math.min(close[2], open[2])
body2   = bodyHi2 - bodyLo2

// Three Inside Up: bearish candle -> small bullish inside (harami) -> bullish close above 1st high
isThreeInsideUp = close[2] < open[2] and body2 > bodyAvg and   // 1st: long bearish
     isWhiteBody[1] and isSmallBody[1] and                       // 2nd: small bullish
     prevBodyHi < bodyHi2 and prevBodyLo > bodyLo2 and           // 2nd inside 1st
     isWhiteBody and close > bodyHi2                              // 3rd: bullish above 1st

// Three Inside Down: bullish candle -> small bearish inside (harami) -> bearish close below 1st low
isThreeInsideDown = close[2] > open[2] and body2 > bodyAvg and
     isBlackBody[1] and isSmallBody[1] and
     prevBodyHi < bodyHi2 and prevBodyLo > bodyLo2 and
     isBlackBody and close < bodyLo2

// Visualization
plotshape(isThreeInsideUp, title="Three Inside Up", location=location.belowbar,
     color=color.new(color.green, 0), style=shape.arrowup, size=size.normal, text="3IU")

plotshape(isThreeInsideDown, title="Three Inside Down", location=location.abovebar,
     color=color.new(color.red, 0), style=shape.arrowdown, size=size.normal, text="3ID")

// Alerts
alertcondition(isThreeInsideUp, "Three Inside Up", "Three Inside Up - bullish reversal confirmation")
alertcondition(isThreeInsideDown, "Three Inside Down", "Three Inside Down - bearish reversal confirmation")
```

---

### 4.4 Pin Bar Detection

```pinescript
//@version=6
indicator("Pin Bar Detector", overlay=true)

// Candle components
bodyHi   = math.max(close, open)
bodyLo   = math.min(close, open)
body     = bodyHi - bodyLo
range_   = high - low
upShadow = high - bodyHi
dnShadow = bodyLo - low

// Pin bar criteria: wick must be >= 2/3 of total range, body in opposite extreme
minWickRatio = input.float(66.0, "Min Wick % of Range", minval=50.0, maxval=85.0) / 100

// Trend detection
sma50 = ta.sma(close, 50)
isDownTrend = close < sma50
isUpTrend   = close > sma50

// Bullish Pin Bar: long lower wick, small body near the top
isBullishPinBar = range_ > 0 and
     dnShadow >= range_ * minWickRatio and       // lower wick >= 66% of range
     body <= range_ * (1 - minWickRatio) and       // body is small
     upShadow < dnShadow * 0.25 and                // minimal upper shadow
     isDownTrend                                     // in a downtrend

// Bearish Pin Bar: long upper wick, small body near the bottom
isBearishPinBar = range_ > 0 and
     upShadow >= range_ * minWickRatio and
     body <= range_ * (1 - minWickRatio) and
     dnShadow < upShadow * 0.25 and
     isUpTrend

// Pin bar strength score (0-100)
bullPinStrength = isBullishPinBar ? math.round(dnShadow / range_ * 100) : 0
bearPinStrength = isBearishPinBar ? math.round(upShadow / range_ * 100) : 0

// Visualization
plotshape(isBullishPinBar, title="Bullish Pin Bar", location=location.belowbar,
     color=color.new(color.green, 0), style=shape.arrowup, size=size.normal, text="BullPin")

plotshape(isBearishPinBar, title="Bearish Pin Bar", location=location.abovebar,
     color=color.new(color.red, 0), style=shape.arrowdown, size=size.normal, text="BearPin")

// Show strength as a label
if isBullishPinBar
    label.new(bar_index, low - ta.atr(30) * 1.2,
         text=str.tostring(bullPinStrength) + "%",
         style=label.style_none, textcolor=color.green, size=size.small)

if isBearishPinBar
    label.new(bar_index, high + ta.atr(30) * 1.2,
         text=str.tostring(bearPinStrength) + "%",
         style=label.style_none, textcolor=color.red, size=size.small)

// Alerts
alertcondition(isBullishPinBar, "Bullish Pin Bar", "Bullish Pin Bar detected")
alertcondition(isBearishPinBar, "Bearish Pin Bar", "Bearish Pin Bar detected")
```

---

## 5. Complete Multi-Pattern Indicator

A single indicator that detects all 20 patterns with toggles for each.

```pinescript
//@version=6
indicator("All Candlestick Patterns v6", overlay=true, max_labels_count=500)

// ============================================================================
// INPUTS
// ============================================================================

// Pattern toggles
showDoji           = input.bool(true, "Show Doji", group="Single Candle")
showHammer         = input.bool(true, "Show Hammer", group="Single Candle")
showShootingStar   = input.bool(true, "Show Shooting Star", group="Single Candle")
showMarubozu       = input.bool(true, "Show Marubozu", group="Single Candle")
showHangingMan     = input.bool(true, "Show Hanging Man", group="Single Candle")
showInvHammer      = input.bool(true, "Show Inverted Hammer", group="Single Candle")

showEngulfing      = input.bool(true, "Show Engulfing", group="Double Candle")
showHarami         = input.bool(true, "Show Harami", group="Double Candle")
showPiercing       = input.bool(true, "Show Piercing/DCC", group="Double Candle")
showTweezer        = input.bool(true, "Show Tweezers", group="Double Candle")
showPinBar         = input.bool(true, "Show Pin Bar", group="Double Candle")

showMorningStar    = input.bool(true, "Show Morning/Evening Star", group="Triple Candle")
showSoldiersCrows  = input.bool(true, "Show 3WS/3BC", group="Triple Candle")
showThreeInside    = input.bool(true, "Show Three Inside", group="Triple Candle")

// Configuration
shadowBodyRatio = input.float(2.0, "Shadow/Body Ratio", minval=1.5, maxval=4.0, group="Config")
trendMethod     = input.string("SMA50", "Trend Detection",
                     options=["SMA50", "SMA50+200", "None"], group="Config")

// ============================================================================
// CORE CALCULATIONS
// ============================================================================

bodyHi    = math.max(close, open)
bodyLo    = math.min(close, open)
body      = bodyHi - bodyLo
range_    = high - low
upShadow  = high - bodyHi
dnShadow  = bodyLo - low
bodyAvg   = ta.ema(body, 14)
atr14     = ta.atr(14)

isWhite    = close > open
isBlack    = close < open
isLong     = body > bodyAvg
isSmall    = body < bodyAvg
isDoji_    = range_ > 0 and body <= range_ * 0.05
smUpShd    = range_ > 0 and range_ * 0.05 > upShadow
smDnShd    = range_ > 0 and range_ * 0.05 > (bodyLo - low)

// Previous bars
pBodyHi  = math.max(close[1], open[1])
pBodyLo  = math.min(close[1], open[1])
pBody    = pBodyHi - pBodyLo
pMid     = pBody / 2 + pBodyLo
pBodyHi2 = math.max(close[2], open[2])
pBodyLo2 = math.min(close[2], open[2])
pBody2   = pBodyHi2 - pBodyLo2
pMid2    = pBody2 / 2 + pBodyLo2

// Trend
sma50  = ta.sma(close, 50)
sma200 = ta.sma(close, 200)
isDnTrend = switch trendMethod
    "SMA50"     => close < sma50
    "SMA50+200" => close < sma50 and sma50 < sma200
    => true
isUpTrend = switch trendMethod
    "SMA50"     => close > sma50
    "SMA50+200" => close > sma50 and sma50 > sma200
    => true

// ============================================================================
// PATTERN DETECTION
// ============================================================================

// --- Single Candle ---
doji = showDoji and isDoji_

hammer = showHammer and isSmall and body > 0 and
     dnShadow >= shadowBodyRatio * body and upShadow < body * 0.3 and
     bodyLo > low + range_ * 0.6 and isDnTrend

invHammer = showInvHammer and isSmall and body > 0 and
     upShadow >= shadowBodyRatio * body and dnShadow < body * 0.3 and
     bodyHi < high - range_ * 0.6 and isDnTrend

shootStar = showShootingStar and isSmall and body > 0 and
     upShadow >= shadowBodyRatio * body and dnShadow < body * 0.3 and
     bodyHi < high - range_ * 0.6 and isUpTrend

hangMan = showHangingMan and isSmall and body > 0 and
     dnShadow >= shadowBodyRatio * body and upShadow < body * 0.3 and
     bodyLo > low + range_ * 0.6 and isUpTrend

bullMarubozu = showMarubozu and isLong and isWhite and
     upShadow <= body * 0.01 and dnShadow <= body * 0.01

bearMarubozu = showMarubozu and isLong and isBlack and
     upShadow <= body * 0.01 and dnShadow <= body * 0.01

// --- Double Candle ---
bullEng = showEngulfing and isDnTrend and isWhite and isLong and
     close[1] < open[1] and bodyHi > pBodyHi and bodyLo < pBodyLo

bearEng = showEngulfing and isUpTrend and isBlack and isLong and
     close[1] > open[1] and bodyHi > pBodyHi and bodyLo < pBodyLo

bullHarami = showHarami and isDnTrend and
     close[1] < open[1] and pBody > bodyAvg and
     isWhite and isSmall and bodyHi < pBodyHi and bodyLo > pBodyLo

bearHarami = showHarami and isUpTrend and
     close[1] > open[1] and pBody > bodyAvg and
     isBlack and isSmall and bodyHi < pBodyHi and bodyLo > pBodyLo

pierce = showPiercing and isDnTrend and
     close[1] < open[1] and pBody > bodyAvg and
     isWhite and isLong and open < low[1] and close > pMid and close < pBodyHi

darkCloud = showPiercing and isUpTrend and
     close[1] > open[1] and pBody > bodyAvg and
     isBlack and isLong and open > high[1] and close < pMid and close > pBodyLo

twzBot = showTweezer and isDnTrend and
     close[1] < open[1] and isWhite and math.abs(low - low[1]) <= atr14 * 0.01

twzTop = showTweezer and isUpTrend and
     close[1] > open[1] and isBlack and math.abs(high - high[1]) <= atr14 * 0.01

bullPin = showPinBar and range_ > 0 and
     dnShadow >= range_ * 0.66 and upShadow < dnShadow * 0.25 and isDnTrend

bearPin = showPinBar and range_ > 0 and
     upShadow >= range_ * 0.66 and dnShadow < upShadow * 0.25 and isUpTrend

// --- Triple Candle ---
mornStar = showMorningStar and isDnTrend and
     close[2] < open[2] and pBody2 > bodyAvg and
     isSmall[1] and pBodyHi < pBodyLo2 and
     isWhite and isLong and bodyHi >= pMid2

eveStar = showMorningStar and isUpTrend and
     close[2] > open[2] and pBody2 > bodyAvg and
     isSmall[1] and pBodyLo > pBodyHi2 and
     isBlack and isLong and bodyLo <= pMid2

threeWS = showSoldiersCrows
bool threeWS_val = false
if threeWS and isLong and isLong[1] and isLong[2]
    if isWhite and isWhite[1] and isWhite[2]
        threeWS_val := close > close[1] and close[1] > close[2] and
             open < close[1] and open > open[1] and
             open[1] < close[2] and open[1] > open[2] and
             smUpShd and smUpShd[1] and smUpShd[2]

threeBC = showSoldiersCrows
bool threeBC_val = false
if threeBC and isLong and isLong[1] and isLong[2]
    if isBlack and isBlack[1] and isBlack[2]
        threeBC_val := close < close[1] and close[1] < close[2] and
             open > close[1] and open < open[1] and
             open[1] > close[2] and open[1] < open[2] and
             smDnShd and smDnShd[1] and smDnShd[2]

threeIU = showThreeInside and
     close[2] < open[2] and pBody2 > bodyAvg and
     isWhite[1] and isSmall[1] and pBodyHi < pBodyHi2 and pBodyLo > pBodyLo2 and
     isWhite and close > pBodyHi2

threeID = showThreeInside and
     close[2] > open[2] and pBody2 > bodyAvg and
     isBlack[1] and isSmall[1] and pBodyHi < pBodyHi2 and pBodyLo > pBodyLo2 and
     isBlack and close < pBodyLo2

// ============================================================================
// VISUALIZATION
// ============================================================================

// Single
plotshape(doji, "Doji", location.abovebar, color.new(color.yellow, 0), shape.diamond, size.tiny, text="D")
plotshape(hammer, "Hammer", location.belowbar, color.new(color.green, 0), shape.triangleup, size.small, text="H")
plotshape(invHammer, "Inv Hammer", location.belowbar, color.new(color.lime, 0), shape.triangleup, size.tiny, text="IH")
plotshape(shootStar, "Shooting Star", location.abovebar, color.new(color.red, 0), shape.triangledown, size.small, text="SS")
plotshape(hangMan, "Hanging Man", location.abovebar, color.new(color.maroon, 0), shape.triangledown, size.tiny, text="HM")
plotshape(bullMarubozu, "Bull Marubozu", location.belowbar, color.new(color.green, 0), shape.arrowup, size.tiny, text="BM")
plotshape(bearMarubozu, "Bear Marubozu", location.abovebar, color.new(color.red, 0), shape.arrowdown, size.tiny, text="BrM")

// Double
plotshape(bullEng, "Bull Engulfing", location.belowbar, color.new(color.green, 0), shape.arrowup, size.normal, text="BE")
plotshape(bearEng, "Bear Engulfing", location.abovebar, color.new(color.red, 0), shape.arrowdown, size.normal, text="BrE")
plotshape(bullHarami, "Bull Harami", location.belowbar, color.new(color.green, 30), shape.triangleup, size.tiny, text="BH")
plotshape(bearHarami, "Bear Harami", location.abovebar, color.new(color.red, 30), shape.triangledown, size.tiny, text="BrH")
plotshape(pierce, "Piercing", location.belowbar, color.new(color.teal, 0), shape.arrowup, size.small, text="PL")
plotshape(darkCloud, "Dark Cloud", location.abovebar, color.new(color.orange, 0), shape.arrowdown, size.small, text="DC")
plotshape(twzBot, "Tweezer Bot", location.belowbar, color.new(color.aqua, 0), shape.triangleup, size.tiny, text="TB")
plotshape(twzTop, "Tweezer Top", location.abovebar, color.new(color.fuchsia, 0), shape.triangledown, size.tiny, text="TT")
plotshape(bullPin, "Bull Pin", location.belowbar, color.new(color.green, 0), shape.flag, size.small, text="BP")
plotshape(bearPin, "Bear Pin", location.abovebar, color.new(color.red, 0), shape.flag, size.small, text="BrP")

// Triple
plotshape(mornStar, "Morning Star", location.belowbar, color.new(color.green, 0), shape.arrowup, size.large, text="MS")
plotshape(eveStar, "Evening Star", location.abovebar, color.new(color.red, 0), shape.arrowdown, size.large, text="ES")
plotshape(threeWS_val, "3 White Soldiers", location.belowbar, color.new(color.green, 0), shape.labelup, size.normal, text="3WS")
plotshape(threeBC_val, "3 Black Crows", location.abovebar, color.new(color.red, 0), shape.labeldown, size.normal, text="3BC")
plotshape(threeIU, "3 Inside Up", location.belowbar, color.new(color.teal, 0), shape.arrowup, size.small, text="3IU")
plotshape(threeID, "3 Inside Down", location.abovebar, color.new(color.orange, 0), shape.arrowdown, size.small, text="3ID")
```

---

## 6. Pattern Detection with Volume Confirmation

Add volume confirmation to any pattern for higher reliability signals.

```pinescript
//@version=6
indicator("Engulfing with Volume Confirmation", overlay=true)

// Candle components
bodyHi  = math.max(close, open)
bodyLo  = math.min(close, open)
body    = bodyHi - bodyLo
bodyAvg = ta.ema(body, 14)

isWhite = close > open
isBlack = close < open
isLong  = body > bodyAvg

pBodyHi = math.max(close[1], open[1])
pBodyLo = math.min(close[1], open[1])

// Trend
sma50     = ta.sma(close, 50)
isDnTrend = close < sma50
isUpTrend = close > sma50

// Volume confirmation
volSMA     = ta.sma(volume, 20)
volMultiplier = input.float(1.5, "Volume Multiplier", minval=1.0, maxval=5.0)
isHighVol  = volume > volSMA * volMultiplier
isVolConfirmed = volume > volume[1]  // current volume exceeds prior

// Engulfing patterns
bullEng = isDnTrend and isWhite and isLong and
     close[1] < open[1] and bodyHi > pBodyHi and bodyLo < pBodyLo

bearEng = isUpTrend and isBlack and isLong and
     close[1] > open[1] and bodyHi > pBodyHi and bodyLo < pBodyLo

// Volume-confirmed signals
bullEngVol = bullEng and isHighVol
bearEngVol = bearEng and isHighVol

// Standard signals (no volume)
bullEngNoVol = bullEng and not isHighVol
bearEngNoVol = bearEng and not isHighVol

// Visualization - strong signals (volume confirmed)
plotshape(bullEngVol, title="Bull Engulfing + Vol",
     location=location.belowbar, color=color.new(color.green, 0),
     style=shape.arrowup, size=size.large, text="BE+V")

plotshape(bearEngVol, title="Bear Engulfing + Vol",
     location=location.abovebar, color=color.new(color.red, 0),
     style=shape.arrowdown, size=size.large, text="BrE+V")

// Weak signals (no volume)
plotshape(bullEngNoVol, title="Bull Engulfing (weak)",
     location=location.belowbar, color=color.new(color.green, 60),
     style=shape.triangleup, size=size.small, text="BE")

plotshape(bearEngNoVol, title="Bear Engulfing (weak)",
     location=location.abovebar, color=color.new(color.red, 60),
     style=shape.triangledown, size=size.small, text="BrE")

// Volume bars at the bottom
plot(volume, "Volume", style=plot.style_columns,
     color=isHighVol ? color.new(color.blue, 30) : color.new(color.gray, 70),
     display=display.pane)
plot(volSMA * volMultiplier, "Vol Threshold", color=color.orange,
     display=display.pane)

// Alerts
alertcondition(bullEngVol, "Bull Engulfing + Volume", "Volume-confirmed Bullish Engulfing!")
alertcondition(bearEngVol, "Bear Engulfing + Volume", "Volume-confirmed Bearish Engulfing!")
```

---

## 7. Pattern Detection with Trend Confirmation

Use multi-timeframe analysis to confirm pattern signals.

```pinescript
//@version=6
indicator("Patterns + MTF Trend Confirmation", overlay=true)

// Higher timeframe input
htf = input.timeframe("D", "Higher Timeframe", group="MTF Settings")

// Current timeframe candle components
bodyHi  = math.max(close, open)
bodyLo  = math.min(close, open)
body    = bodyHi - bodyLo
range_  = high - low
dnShadow = bodyLo - low
bodyAvg = ta.ema(body, 14)
isSmall = body < bodyAvg
factor  = input.float(2.0, "Shadow/Body Ratio", group="Pattern Settings")

// Higher timeframe trend
htfSma50  = request.security(syminfo.tickerid, htf, ta.sma(close, 50))
htfSma200 = request.security(syminfo.tickerid, htf, ta.sma(close, 200))
htfClose  = request.security(syminfo.tickerid, htf, close)

htfBullish = htfClose > htfSma50
htfBearish = htfClose < htfSma50
htfStrongBull = htfClose > htfSma50 and htfSma50 > htfSma200
htfStrongBear = htfClose < htfSma50 and htfSma50 < htfSma200

// Current timeframe trend
sma50     = ta.sma(close, 50)
isDnTrend = close < sma50
isUpTrend = close > sma50

// Hammer detection (current timeframe)
isHammer = isSmall and body > 0 and
     dnShadow >= factor * body and
     (high - bodyHi) < body * 0.3 and
     bodyLo > low + range_ * 0.6 and
     isDnTrend

// MTF confirmed Hammer: pattern on current TF + bullish higher TF
hammerMTF = isHammer and htfBullish
hammerStrongMTF = isHammer and htfStrongBull

// Shooting Star detection (current timeframe)
upShadow = high - bodyHi
isShootingStar = isSmall and body > 0 and
     upShadow >= factor * body and
     dnShadow < body * 0.3 and
     bodyHi < high - range_ * 0.6 and
     isUpTrend

// MTF confirmed Shooting Star
shootStarMTF = isShootingStar and htfBearish
shootStarStrongMTF = isShootingStar and htfStrongBear

// Visualization
plotshape(hammerStrongMTF, "Hammer (Strong MTF)", location.belowbar,
     color.new(color.green, 0), shape.arrowup, size.large, text="H++")

plotshape(hammerMTF and not hammerStrongMTF, "Hammer (MTF)", location.belowbar,
     color.new(color.green, 0), shape.arrowup, size.normal, text="H+")

plotshape(isHammer and not hammerMTF, "Hammer (No MTF)", location.belowbar,
     color.new(color.green, 60), shape.triangleup, size.small, text="H")

plotshape(shootStarStrongMTF, "Shooting Star (Strong MTF)", location.abovebar,
     color.new(color.red, 0), shape.arrowdown, size.large, text="SS++")

plotshape(shootStarMTF and not shootStarStrongMTF, "Shooting Star (MTF)", location.abovebar,
     color.new(color.red, 0), shape.arrowdown, size.normal, text="SS+")

plotshape(isShootingStar and not shootStarMTF, "Shooting Star (No MTF)", location.abovebar,
     color.new(color.red, 60), shape.triangledown, size.small, text="SS")

// HTF trend background
bgcolor(htfStrongBull ? color.new(color.green, 95) :
     htfBullish ? color.new(color.green, 97) :
     htfStrongBear ? color.new(color.red, 95) :
     htfBearish ? color.new(color.red, 97) : na, title="HTF Trend Background")

// Plot HTF MAs
plot(htfSma50, "HTF SMA50", color.blue, linewidth=2)
plot(htfSma200, "HTF SMA200", color.orange, linewidth=2)

// Alerts
alertcondition(hammerStrongMTF, "Strong MTF Hammer", "Hammer with strong MTF trend alignment!")
alertcondition(shootStarStrongMTF, "Strong MTF Shooting Star", "Shooting Star with strong MTF alignment!")
```

---

## Notes on Pine Script v6 Compatibility

1. **`indicator()` function:** Pine Script v6 uses `indicator()` instead of the older `study()`. All examples above use the v6 `indicator()` function.

2. **Namespace functions:** v6 requires namespaced functions like `ta.sma()`, `ta.ema()`, `ta.atr()`, `ta.rsi()`, `math.max()`, `math.min()`, `math.abs()`, `math.round()`, `str.tostring()`.

3. **`request.security()`:** For multi-timeframe data, use `request.security()` (replaces the older `security()` function).

4. **Variable declarations:** Use `var` for persistent variables and standard assignment for recalculating variables. Use `:=` for reassignment within conditional blocks.

5. **Input functions:** Use `input.float()`, `input.int()`, `input.bool()`, `input.string()`, `input.color()`, `input.timeframe()` with named parameters.

6. **Color transparency:** Use `color.new(color.green, 0)` for opaque and `color.new(color.green, 90)` for 90% transparent.

7. **Label management:** Set `max_labels_count` in the `indicator()` call when using `label.new()` to avoid hitting the default limit.

---

*All code examples are designed for TradingView's Pine Script v6 runtime. Test on paper trading before using in live markets.*
