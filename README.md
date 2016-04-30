[![Build Status](https://travis-ci.org/qznc/d-money.svg?branch=master)](https://travis-ci.org/qznc/d-money)

# D-Money

Provide a money data type, for easy and safe handling of currency amounts.

Floating point is imprecise. Integer is fragile.
Both lack convenience, e.g. for rounding.

Features:

* support different rounding modes
* cannot mix currencies (e.g. EUR vs USD)
* efficient (faster than BigNum)
* overflow checking for arithmetic

Scope is smaller than JSR 354, for example,
which also considers conversion and meta data.
A conversion rate depends on target date and time,
the currencies involved, the provider, the amount, and other factors.
If you need meta data,
then wrap `money` into your own data type.

Internally, this uses a `long` data type.
This limits the numbers depending on the number of decimals specified.
A plain `money!"EUR"` type has a max of
922337203685477.5807EUR,
roughly 922 trillion.
