# D-Money

Provide a money data type, for easy and safe handling of currency amounts.

Floating point is imprecise. Integer is fragile.
Both lack convenience, e.g. for rounding.

Features:

* support different rounding modes
* cannot mix currencies (e.g. EUR vs USD)
* efficient (faster than BigNum)
* overflow checking for arithmetic

Internally, this uses a `long` data type.
This limits the numbers depending on the number of decimals specified.
A plain `money!"EUR"` type has a max of
922337203685477.5807EUR,
roughly 922 trillion.
