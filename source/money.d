import std.math : pow, floor, ceil, lrint;
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
    /** Round to nearest number, half way between round up */
    HALF_UP,
    /** Round to nearest number, half way between round down */
    HALF_DOWN,
    /** Round to nearest number, half way between round to even number */
    HALF_EVEN,
    // also add:
    // HALF_ODD,
    // HALF_TO_ZERO aka TRUNC,
    // HALF_FROM_ZERO,
    /** Error if rounding would be necessary */
    UNNECESSARY
}

/** Round an integer to a certain decimal place according to rounding mode */
pure nothrow @nogc @trusted
long round(long x, int dec_place, roundingMode m)
out (result) {
    assert ((result % pow(10, dec_place)) == 0);
}
body {
    const zeros = pow(10, dec_place);
    const half  = zeros / 2;
    final switch (m) with (roundingMode) {
        case CEILING: goto case;
        case UP:
            if ((x % zeros) != 0)
                return ((x / zeros) + 1) * zeros;
            goto case;
        case FLOOR: goto case;
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
        case HALF_EVEN: return x; // FIXME
        case UNNECESSARY:
            assert ((x % zeros) == 0);
            return x;
    }
}

///
unittest {
    assert (round(1001, 1, roundingMode.DOWN) == 1000);
    assert (round(1001, 1, roundingMode.UP)   == 1010);
    assert (round(1005, 1, roundingMode.HALF_UP) == 1010);
    assert (round(1005, 1, roundingMode.HALF_DOWN) == 1000);
}

/** Round a float to an integer according to rounding mode */
pure nothrow @nogc @trusted
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
        case UNNECESSARY:
            assert (x == ceil(x) && x == floor(x));
            return x;
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
