# D-Money

Provide a money data type, for easy and safe handling of currency amounts.

Floating point is imprecise. Integer is fragile.
Both lack convenience functions, e.g. for rounding.

Planned Features:

* support different rounding modes
* prevent mixing currencies via type system (EUR vs USD)
* efficiency (faster than BigNum)
* overflow checking (and similar correctness dangers)
* sacrifice dynamicity for efficiency (currency is static information)
