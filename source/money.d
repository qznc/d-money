/******
 * Handling money amounts safely and efficiently.
 *
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors: Andreas Zwinkau
 */
module money;

import std.math : floor, ceil, lrint, abs;
import std.conv : to;
import core.checkedint : adds, subs, muls, negs;
import std.format : FormatSpec, formattedWrite;

@nogc pure @safe nothrow
private long pow10(int x) {
    if (x <= 0) return 1;
    return 10 * pow10(x-1);
}

/** Holds an amount of money **/
struct money(string curr, int dec_places = 4, roundingMode rmode = roundingMode.HALF_UP) {
    alias T = typeof(this);
    long amount;

    this(double x) {
        amount = to!long(round(x * pow10(dec_places), rmode));
    }

    private static T fromLong(long a) {
        T ret = void;
        ret.amount = a;
        return ret;
    }

    /// default initialisation value is zero
    static immutable init = fromLong(0L);
    /// maximum amount depends on dec_places
    static immutable max = fromLong(long.max);
    /// minimum amount depends on dec_places
    static immutable min = fromLong(long.min);

    private static immutable dec_mask = pow10(dec_places);

    T opBinary(string op)(const T rhs) const
    {
        static if (op == "+") {
            bool overflow;
            auto ret = fromLong(adds(amount, rhs.amount, overflow));
            if (overflow)
                throw new OverflowException();
            return ret;
        } else static if (op == "-") {
            bool overflow;
            auto ret = fromLong(subs(amount, rhs.amount, overflow));
            if (overflow)
                throw new OverflowException();
            return ret;
        }
        // TODO support * / % ? Might be useful for taxes etc.
        else static assert(0, "Operator "~op~" not implemented");
    }

    T opBinary(string op)(const long rhs) const
    {
        static if (op == "*") {
            bool overflow;
            auto ret = fromLong(muls(amount, rhs, overflow));
            if (overflow)
                throw new OverflowException();
            return ret;
        } else static if (op == "/") {
            return fromLong(amount / rhs);
        } else static if (op == "%") {
            const intpart = amount / pow10(dec_places);
            return fromLong(intpart % rhs * pow10(dec_places));
        }
        // TODO support * / % ? Might be useful for taxes etc.
        else static assert(0, "Operator "~op~" not implemented");
    }

    bool opEquals()(auto ref const T other) const
    {
        return other.amount == amount;
    }

    int opCmp(const T other) const
    {
        if (other.amount > this.amount) return -1;
        if (other.amount < this.amount) return 1;
        return 0;
    }

    void toString(scope void delegate(const(char)[]) sink,
            FormatSpec!char fmt) const
    {
        switch(fmt.spec)
        {
            case 's': /* default e.g. for writeln */
                goto case;
            case 'f':
                formattedWrite(sink, "%d", (amount / dec_mask));
                sink(".");
                auto decimals = amount % dec_mask;
                if (fmt.precision < dec_places) {
                    auto n = dec_places - fmt.precision;
                    decimals = round!(rmode)(decimals,n);
                    decimals = decimals / pow10(n);
                }
                formattedWrite(sink, "%d", decimals);
                sink(curr);
                break;
            case 'd':
                auto ra = round!rmode(amount, dec_places);
                formattedWrite(sink, "%d", (ra / dec_mask));
                sink(curr);
                break;
            default:
                throw new Exception("Unknown format specifier: %" ~
                        fmt.spec);
        }
    }
}

/// Basic usage
unittest {
    import std.stdio;
    alias EUR = money!("EUR");
    assert (EUR(100.0001) == EUR(100.00009));
    alias USD = money!("USD");
    //assert (EUR(10) == USD(10)); // does not compile
    assert (EUR(3.10) + EUR(1.40) == EUR(4.50));
    assert (EUR(3.10) - EUR(1.40) == EUR(1.70));

    import std.format : format;
    // for writefln("%d", EUR(3.6));
    assert(format("%d", EUR(3.6)) == "4EUR");
    assert(format("%d", EUR(3.1)) == "3EUR");
    // for writefln("%f", EUR(3.141592));
    assert(format("%f", EUR(3.141592)) == "3.1416EUR");
    assert(format("%.2f", EUR(3.145)) == "3.15EUR");
}

/// Overflow is an error, since silent corruption is worse
unittest {
    import std.exception : assertThrown;
    alias EUR = money!("EUR");
    auto one = EUR(1);
    assertThrown!OverflowException(EUR.max + one);
    assertThrown!OverflowException(EUR.min - one);
}

unittest {
    alias EUR = money!("EUR");
    assert(EUR(5) < EUR(6));
    assert(EUR(6) > EUR(5));
    assert(EUR(5) == EUR(5));
    assert(EUR(6) != EUR(5));
}

unittest {
    alias EUR = money!("EUR");
    auto x = EUR(42);
    assert(EUR(84) == x * 2);
    //x = x * x; // does not compile
    assert(EUR(21) == x / 2);
    assert(EUR(2) == x % 4);
}

unittest {
    import std.exception : assertThrown;
    alias EURa = money!("EUR", 2);
    alias EURb = money!("EUR", 4);
    auto x = EURa(1.01);
    auto y = EURb(1.0001);
    assert(x > y);
    assert(x+y > y);
    assert(x+y > x);
    x = y;
    assert(x == EURa(1));
    x = EURa.max;
    assertThrown!OverflowException(y = x);
}

/** Specifies rounding behavior **/
enum roundingMode {
    /** Round upwards, e.g. 3.1 up to 4. */
    UP,
    /** Round downwards, e.g. 3.9 down to 3. */
    DOWN,
    /** Round to nearest number, half way between round up, e.g. 3.5 to 4. */
    HALF_UP,
    /** Round to nearest number, half way between round dow, e.g. 3.5 to 3.  */
    HALF_DOWN,
    /** Round to nearest number, half way between round to even number, e.g. 3.5 to 4. */
    HALF_EVEN,
    /** Round to nearest number, half way between round to odd number, e.g. 3.5 to 3. */
    HALF_ODD,
    /** Round to nearest number, half way between round towards zero, e.g. -3.5 to -3.  */
    HALF_TO_ZERO,
    /** Round to nearest number, half way between round away from zero, e.g. -3.5 to -4.  */
    HALF_FROM_ZERO,
    /** Throw exception if rounding would be necessary */
    UNNECESSARY
}

/** Round an integer to a certain decimal place according to rounding mode */
long round(roundingMode m)(long x, int dec_place)
out (result) {
    assert ((result % pow10(dec_place)) == 0);
}
body {
    const zeros = pow10(dec_place);
    /* short cut, also removes edge cases */
    if ((x % zeros) == 0)
        return x;

    const half  = zeros / 2;
    with (roundingMode) {
        static if (m == UP) {
            return ((x / zeros) + 1) * zeros;
        } else static if (m == DOWN) {
            return x / zeros * zeros;
        } else static if (m == HALF_UP) {
            if ((x % zeros) >= half)
                return ((x / zeros) + 1) * zeros;
            else
                return x / zeros * zeros;
        } else static if (m == HALF_DOWN) {
            if ((x % zeros) > half)
                return ((x / zeros) + 1) * zeros;
            else
                return x / zeros * zeros;
        } else static if (m == HALF_EVEN) {
            const down = x / zeros;
            if (down % 2 == 0)
                return down * zeros;
            else
                return (down+1) * zeros;
        } else static if (m == HALF_ODD) {
            const down = x / zeros;
            if (down % 2 == 0)
                return (down+1) * zeros;
            else
                return down * zeros;
        } else static if (m == HALF_TO_ZERO) {
            const down = x / zeros;
            if (down < 0) {
                if (abs(x % zeros) <= half) {
                    return (down) * zeros;
                } else {
                    return (down-1) * zeros;
                }
            } else {
                if ((x % zeros) > half) {
                    return (down+1) * zeros;
                } else {
                    return (down) * zeros;
                }
            }
        } else static if (m == HALF_FROM_ZERO) {
            const down = x / zeros;
            if (down < 0) {
                if (abs(x % zeros) < half) {
                    return (down) * zeros;
                } else {
                    return (down-1) * zeros;
                }
            } else {
                if (x % zeros >= half) {
                    return (down+1) * zeros;
                } else {
                    return (down) * zeros;
                }
            }
        } else static if (m == UNNECESSARY) {
            throw new ForbiddenRounding();
        }
    }
}

///
unittest {
    assert (round!(roundingMode.DOWN)     (1009, 1) == 1000);
    assert (round!(roundingMode.UP)       (1001, 1) == 1010);
    assert (round!(roundingMode.HALF_UP)  (1005, 1) == 1010);
    assert (round!(roundingMode.HALF_DOWN)(1005, 1) == 1000);
}

@safe pure @nogc nothrow
unittest {
    assert (round!(roundingMode.HALF_UP)       ( 10, 1) ==  10);
    assert (round!(roundingMode.UP)            ( 11, 1) ==  20);
    assert (round!(roundingMode.DOWN)          ( 19, 1) ==  10);
    assert (round!(roundingMode.HALF_UP)       ( 15, 1) ==  20);
    assert (round!(roundingMode.HALF_UP)       (-15, 1) == -10);
    assert (round!(roundingMode.HALF_DOWN)     ( 15, 1) ==  10);
    assert (round!(roundingMode.HALF_DOWN)     ( 16, 1) ==  20);
    assert (round!(roundingMode.HALF_EVEN)     ( 15, 1) ==  20);
    assert (round!(roundingMode.HALF_EVEN)     ( 25, 1) ==  20);
    assert (round!(roundingMode.HALF_ODD)      ( 15, 1) ==  10);
    assert (round!(roundingMode.HALF_ODD)      ( 25, 1) ==  30);
    assert (round!(roundingMode.HALF_TO_ZERO)  ( 25, 1) ==  20);
    assert (round!(roundingMode.HALF_TO_ZERO)  ( 26, 1) ==  30);
    assert (round!(roundingMode.HALF_TO_ZERO)  (-25, 1) == -20);
    assert (round!(roundingMode.HALF_TO_ZERO)  (-26, 1) == -30);
    assert (round!(roundingMode.HALF_FROM_ZERO)( 25, 1) ==  30);
    assert (round!(roundingMode.HALF_FROM_ZERO)( 24, 1) ==  20);
    assert (round!(roundingMode.HALF_FROM_ZERO)(-25, 1) == -30);
    assert (round!(roundingMode.HALF_FROM_ZERO)(-24, 1) == -20);
}

unittest {
    import std.exception : assertThrown;
    assert (round!(roundingMode.UNNECESSARY)   ( 10, 1) ==  10);
    assertThrown!ForbiddenRounding(round!(roundingMode.UNNECESSARY)(12, 1) == 10);
}

/** Round a float to an integer according to rounding mode */
//pure nothrow @nogc @trusted
real round(real x, roundingMode m)
body {
    final switch (m) with (roundingMode) {
        case UP: return ceil(x);
        case DOWN: return floor(x);
        case HALF_UP: return lrint(x);
        case HALF_DOWN: return lrint(x);
        case HALF_EVEN: return lrint(x);
        case HALF_ODD: return x; // FIXME
        case HALF_TO_ZERO: return x; // FIXME
        case HALF_FROM_ZERO: return x; // FIXME
        case UNNECESSARY:
            throw new ForbiddenRounding();
    }
}

/** Exception is thrown if rounding would have to happen,
    but roundingMode.UNNECESSARY is specified. */
class ForbiddenRounding : Exception {
    public
    {
        @safe pure nothrow this(
                string file =__FILE__,
                size_t line = __LINE__,
                Throwable next = null)
        {
            super("Rounding is forbidden", file, line, next);
        }
    }
}

/** Overflow would happen with money arithmetic. */
class OverflowException : Exception {
    public
    {
        @safe pure nothrow this(
                string file =__FILE__,
                size_t line = __LINE__,
                Throwable next = null)
        {
            super("Overflow", file, line, next);
        }
    }
}

