[![Build Status](https://travis-ci.org/qznc/d-money.svg?branch=master)](https://travis-ci.org/qznc/d-money)
[![Coverage Status](https://coveralls.io/repos/github/qznc/d-money/badge.svg?branch=master)](https://coveralls.io/github/qznc/d-money?branch=master)
[![Dub Package](https://img.shields.io/dub/v/money.svg)](https://code.dlang.org/packages/money)

# D-Money

Handling amounts of money safely and efficiently.

Floating point is imprecise. Integer is fragile.
BigNum and similar are slow.
All lack type safety, like forbidding addition different currencies.

Features:

* support different rounding modes
* can not mix currencies (e.g. EUR vs USD)
* efficient integer arithmetic
* overflow checking for arithmetic
* type checking for currencies, precision, and rounding mode
* yet generic equality and comparison


```d
    alias EUR = currency!("EUR");

    assert(EUR(100.0001) == EUR(100.00009));
    assert(EUR(3.10) + EUR(1.40) == EUR(4.50));
    assert(EUR(3.10) - EUR(1.40) == EUR(1.70));
    assert(EUR(10.01) * 1.1 == EUR(11.011));

    writefln("%d", EUR(3.6)); // "4EUR"
    writefln("%f", EUR(3.141592)); // "3.1416EUR"
    writefln("%.2f", EUR(3.145)); // "3.15EUR"
```

Scope is smaller than JSR 354, for example,
which also considers conversion and meta data.
A conversion rate depends on target date and time,
the currencies involved, the provider, the amount, and other factors.
If you need meta data,
then wrap `currency` into your own data type.

Available via [dub on code.dlang.org](http://code.dlang.org/packages/money).

DDoc documentation on [Github pages](https://qznc.github.io/d-money/).

Licence is Boost v1.0.
