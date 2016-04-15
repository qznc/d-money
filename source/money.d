import std.math : pow, floor, ceil, lrint, abs;
import std.conv : to;

/** Specifies rounding behavior

Inspired by java.math.RoundingMode.
**/
enum roundingMode {
    /** Round upwards */
    UP,
    /** Round downwards */
    DOWN,
    /** See UP */
    CEILING,
    /** See DOWN */
    FLOOR,
    /** See DOWN */
    TRUNC,
    /** Round to nearest number, half way between round up */
    HALF_UP,
    /** Round to nearest number, half way between round down */
    HALF_DOWN,
    /** Round to nearest number, half way between round to even number */
    HALF_EVEN,
    /** Round to nearest number, half way between round to odd number */
    HALF_ODD,
    /** Round to nearest number, half way between round towards zero  */
    HALF_TO_ZERO,
    /** Round to nearest number, half way between round away from zero  */
    HALF_FROM_ZERO,
    /** Error if rounding would be necessary */
    UNNECESSARY
}

/** Round an integer to a certain decimal place according to rounding mode */
long round(roundingMode m)(long x, int dec_place)
out (result) {
    assert ((result % pow(10, dec_place)) == 0);
}
body {
    const zeros = pow(10, dec_place);
    /* short cut, also removes edge cases */
    if ((x % zeros) == 0)
        return x;

    const half  = zeros / 2;
    final switch (m) with (roundingMode) {
        case CEILING: goto case;
        case UP:
            return ((x / zeros) + 1) * zeros;
        case FLOOR: goto case;
        case TRUNC: goto case;
        case DOWN: return x / zeros * zeros;
        case HALF_UP:
            if ((x % zeros) >= half)
                return ((x / zeros) + 1) * zeros;
            else
                return x / zeros * zeros;
        case HALF_DOWN:
            if ((x % zeros) > half)
                return ((x / zeros) + 1) * zeros;
            else
                return x / zeros * zeros;
        case HALF_EVEN:
            const down = x / zeros;
            if (down % 2 == 0)
                return down * zeros;
            else
                return (down+1) * zeros;
        case HALF_ODD:
            const down = x / zeros;
            if (down % 2 == 0)
                return (down+1) * zeros;
            else
                return down * zeros;
        case HALF_TO_ZERO:
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
        case HALF_FROM_ZERO:
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
        case UNNECESSARY:
            throw forbiddenRounding;
    }
}

///
unittest {
    assert (round!(roundingMode.DOWN)     (1001, 1) == 1000);
    assert (round!(roundingMode.UP)       (1001, 1) == 1010);
    assert (round!(roundingMode.HALF_UP)  (1005, 1) == 1010);
    assert (round!(roundingMode.HALF_DOWN)(1005, 1) == 1000);
}

// nothrow TODO
unittest {
    assert (round!(roundingMode.HALF_UP)       ( 10, 1) ==  10);
    assert (round!(roundingMode.CEILING)       ( 11, 1) ==  20);
    assert (round!(roundingMode.FLOOR)         ( 19, 1) ==  10);
    assert (round!(roundingMode.TRUNC)         ( 19, 1) ==  10);
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
        case CEILING: goto case;
        case UP: return ceil(x);
        case FLOOR: goto case;
        case DOWN: return floor(x);
        case HALF_UP: return lrint(x);
        case HALF_DOWN: return lrint(x);
        case HALF_EVEN: return lrint(x);
        case HALF_ODD: return x; // FIXME
        case TRUNC: goto case;
        case HALF_TO_ZERO: return x; // FIXME
        case HALF_FROM_ZERO: return x; // FIXME
        case UNNECESSARY:
            throw forbiddenRounding;
    }
}

/** Holds an amount of money **/
struct money(string curr, int dec_places = 4, roundingMode rmode = roundingMode.HALF_UP) {
    long amount;

    this(long x) {
        amount = x * pow(10, dec_places);
    }
    this(double x) {
        amount = to!long(round(x * pow(10.0, dec_places), rmode));
    }
}

///
unittest {
    import std.stdio;
    alias EUR = money!("EUR");
    alias USD = money!("USD");
    assert (EUR(100.0001) == EUR(100.00009));
    //assert (EUR(10) == USD(10)); // does not compile
}

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
private immutable static forbiddenRounding = new ForbiddenRounding();

