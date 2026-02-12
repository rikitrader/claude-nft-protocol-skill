<!-- source: https://www.tradingview.com/pine-script-docs/language/identifiers -->
<!-- scraped: pine-script-docs v6 -->

[User Manual](/pine-script-docs)  / [Language](/pine-script-docs/language/execution-model) / Identifiers        
# Identifiers

Identifiers are names used for user-defined variables and functions:

- They must begin with an uppercase (`A-Z`) or lowercase (`a-z`)
letter, or an underscore (`_`).

- The next characters can be letters, underscores or digits (`0-9`).

- They are case-sensitive.

Here are some examples:

[Pine Script®](https://tradingview.com/pine-script-docs)Copied`myVar_myVarmy123VarfunctionNameMAX_LENmax_lenmaxLen3barsDown  // NOT VALID!`

The Pine Script® [Style Guide](/pine-script-docs/writing/style-guide/) recommends using uppercase SNAKE_CASE for constants, and
camelCase for other identifiers:

[Pine Script®](https://tradingview.com/pine-script-docs)Copied`GREEN_COLOR = #4CAF50MAX_LOOKBACK = 100int fastLength = 7// Returns 1 if the argument is `true`, 0 if it is `false` or `na`.zeroOne(boolValue) => boolValue ? 1 : 0`        [Previous       Script structure](/pine-script-docs/language/script-structure)  [Next   Variable declarations](/pine-script-docs/language/variable-declarations)