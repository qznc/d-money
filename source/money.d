/******
 * Handling amounts of money safely and efficiently.
 *
 * Amounts of money means that this is about numbers and they are tagged
 * with a currency id like "EUR" or "USD".
 * This modules wants to be a good 80% solution.
 * Not applicable for any situation, but most of them
 * and provide something better than anything easy.
 *
 * Handling money safely means to avoid programming errors, which
 * lead to money vanishing to the unknown (e.g. rounding errors).
 * Deterministic arithmetic is necessary.
 *
 * Handling money efficiently means to provide good performance.
 * Mostly in contrast to using something with arbitrary precision,
 * like std.bigint or GNU BigNum.
 *
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors: Andreas Zwinkau
 */
module money;

import std.math : floor, ceil, lrint, abs, FloatingPointControl;
import std.conv : to;
import core.checkedint : adds, subs, muls, negs;
import std.format : FormatSpec, formattedWrite;
import std.traits : hasMember;

@nogc pure @safe nothrow private long pow10(int x)
{
    if (x <= 0)
        return 1;
    return 10 * pow10(x - 1);
}

/** Holds an amount of money **/
struct money(string currency, int dec_places = 4, roundingMode rmode = roundingMode.HALF_UP)
{
    alias T = typeof(this);
    enum __currency = currency;
    enum __dec_places = dec_places;
    enum __rmode = rmode;
    long amount;

    /// Usual contructor. Uses rmode on x.
    this(double x)
    {
        amount = to!long(round(x * pow10(dec_places), rmode));
    }

    private static T fromLong(long a)
    {
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

    /// Can add and subtract money amounts of the same type.
    T opBinary(string op)(const T rhs) const
    {
        static if (op == "+")
        {
            bool overflow;
            auto ret = fromLong(adds(amount, rhs.amount, overflow));
            if (overflow)
                throw new OverflowException();
            return ret;
        }
        else static if (op == "-")
        {
            bool overflow;
            auto ret = fromLong(subs(amount, rhs.amount, overflow));
            if (overflow)
                throw new OverflowException();
            return ret;
        }
        // TODO support * / % ? Might be useful for taxes etc.
        else
            static assert(0, "Operator " ~ op ~ " not implemented");
    }

    /// Can multiply, divide, and modulo with integer values.
    T opBinary(string op)(const long rhs) const
    {
        static if (op == "*")
        {
            bool overflow;
            auto ret = fromLong(muls(amount, rhs, overflow));
            if (overflow)
                throw new OverflowException();
            return ret;
        }
        else static if (op == "/")
        {
            return fromLong(amount / rhs);
        }
        else static if (op == "%")
        {
            const intpart = amount / pow10(dec_places);
            return fromLong(intpart % rhs * pow10(dec_places));
        }
        // TODO support * / % ? Might be useful for taxes etc.
        else
            static assert(0, "Operator " ~ op ~ " not implemented");
    }

    /// Can multiply, divide, and modulo floating point numbers.
    T opBinary(string op)(const real rhs) const
    {
        static if (op == "*")
        {
            const converted = T(rhs);
            bool overflow = false;
            const result = muls(amount, converted.amount, overflow);
            if (overflow)
                throw new OverflowException();
            return fromLong(result / pow10(dec_places));
        }
        else static if (op == "/")
        {
            const converted = T(rhs);
            bool overflow = false;
            auto mult = muls(amount, pow10(dec_places), overflow);
            if (overflow)
                throw new OverflowException();
            return fromLong(mult / converted.amount);
        }
        else static if (op == "%")
        {
            const converted = T(rhs);
            return fromLong(amount % converted.amount);
        }
        // TODO support * / % ? Might be useful for taxes etc.
        else
            static assert(0, "Operator " ~ op ~ " not implemented");
    }

    /// Can check equality with money amounts of the same concurrency and decimal places.
    bool opEquals(OT)(auto ref const OT other) const if (isMoney!OT
            && other.__currency == currency && other.__dec_places == dec_places)
    {
        return other.amount == amount;
    }

    /// Can compare with money amounts of the same concurrency.
    int opCmp(OT)(const OT other) const if (isMoney!OT && other.__currency == currency)
    {
        static if (dec_places == other.__dec_places)
        {
            if (other.amount > this.amount)
                return -1;
            if (other.amount < this.amount)
                return 1;
            return 0;
        }
        else static if (dec_places < other.__dec_places)
        {
            /* D implicitly makes this work for case '>' */
            auto nthis = this * pow10(other.__dec_places - dec_places);
            /* overflow check included */
            if (other.amount > nthis.amount)
                return -1;
            if (other.amount < nthis.amount)
                return 1;
            return 0;
        }
        else
            static assert(0, "opCmp with such 'other' not implemented");
    }

    /// Can convert to string.
    void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt) const
    {
        switch (fmt.spec)
        {
        case 's': /* default e.g. for writeln */
            goto case;
        case 'f':
            formattedWrite(sink, "%d", (amount / dec_mask));
            sink(".");
            auto decimals = amount % dec_mask;
            if (fmt.precision < dec_places)
            {
                auto n = dec_places - fmt.precision;
                decimals = round!(rmode)(decimals, n);
                decimals = decimals / pow10(n);
            }
            formattedWrite(sink, "%d", decimals);
            sink(currency);
            break;
        case 'd':
            auto ra = round!rmode(amount, dec_places);
            formattedWrite(sink, "%d", (ra / dec_mask));
            sink(currency);
            break;
        default:
            throw new Exception("Unknown format specifier: %" ~ fmt.spec);
        }
    }
}

/// Basic usage
unittest
{
    alias EUR = money!("EUR");
    assert(EUR(100.0001) == EUR(100.00009));
    assert(EUR(3.10) + EUR(1.40) == EUR(4.50));
    assert(EUR(3.10) - EUR(1.40) == EUR(1.70));
    assert(EUR(10.01) * 1.1 == EUR(11.011));

    import std.format : format;

    // for writefln("%d", EUR(3.6));
    assert(format("%d", EUR(3.6)) == "4EUR");
    assert(format("%d", EUR(3.1)) == "3EUR");
    // for writefln("%f", EUR(3.141592));
    assert(format("%f", EUR(3.141592)) == "3.1416EUR");
    assert(format("%.2f", EUR(3.145)) == "3.15EUR");
}

/// Overflow is an error, since silent corruption is worse
unittest
{
    import std.exception : assertThrown;

    alias EUR = money!("EUR");
    auto one = EUR(1);
    assertThrown!OverflowException(EUR.max + one);
    assertThrown!OverflowException(EUR.min - one);
}

/// Arithmetic ignores rounding mode
unittest
{
    alias EUR = money!("EUR", 2, roundingMode.UP);
    auto one = EUR(1);
    assert(one != one / 3);
}

/// Generic equality and order
unittest
{
    alias USD = money!("USD", 2);
    alias EURa = money!("EUR", 2);
    alias EURb = money!("EUR", 4);
    alias EURc = money!("EUR", 4, roundingMode.DOWN);
    // cannot compile with different currencies
    static assert(!__traits(compiles, EURa(1) == USD(1)));
    // cannot compile with different dec_places
    static assert(!__traits(compiles, EURa(1) == EURb(1)));
    // can check equality if only rounding mode differs
    assert(EURb(1.01) == EURc(1.01));
    // cannot compare with different currencies
    static assert(!__traits(compiles, EURa(1) < USD(1)));
}

enum isMoney(T) = (hasMember!(T, "amount") && hasMember!(T, "__dec_places")
        && hasMember!(T, "__rmode"));
static assert(isMoney!(money!"EUR"));

unittest {
    alias EUR = money!("EUR");
    import std.format : format;
    assert(format("%s", EUR(3.1)) == "3.1000EUR");

    import std.exception : assertThrown;
    assertThrown!Exception(format("%x", EUR(3.1)));
}

unittest
{
    alias EUR = money!("EUR");
    assert(EUR(5) < EUR(6));
    assert(EUR(6) > EUR(5));
    assert(EUR(5) >= EUR(5));
    assert(EUR(5) == EUR(5));
    assert(EUR(6) != EUR(5));

    import std.exception : assertThrown;
    assertThrown!OverflowException(EUR.max * 2);
    assertThrown!OverflowException(EUR.max * 2.0);
}

unittest
{
    alias EUR = money!("EUR");
    auto x = EUR(42);
    assert(EUR(84) == x * 2);
    static assert(!__traits(compiles, x * x));
    assert(EUR(21) == x / 2);
    assert(EUR(2) == x % 4);
}

unittest
{
    alias EURa = money!("EUR", 2);
    alias EURb = money!("EUR", 4);
    auto x = EURa(1.01);
    assert(x > EURb(1.0001));
    assert(x < EURb(1.0101));
    assert(x <= EURb(1.01));
}

/** Specifies rounding behavior **/
enum roundingMode
{
    // dfmt off
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
    // dfmt on
}

/** Round an integer to a certain decimal place according to rounding mode */
long round(roundingMode m)(long x, int dec_place)
out (result)
{
    assert((result % pow10(dec_place)) == 0);
}
body
{
    const zeros = pow10(dec_place);
    /* short cut, also removes edge cases */
    if ((x % zeros) == 0)
        return x;

    const half = zeros / 2;
    with (roundingMode)
    {
        static if (m == UP)
        {
            return ((x / zeros) + 1) * zeros;
        }
        else static if (m == DOWN)
        {
            return x / zeros * zeros;
        }
        else static if (m == HALF_UP)
        {
            if ((x % zeros) >= half)
                return ((x / zeros) + 1) * zeros;
            else
                return x / zeros * zeros;
        }
        else static if (m == HALF_DOWN)
        {
            if ((x % zeros) > half)
                return ((x / zeros) + 1) * zeros;
            else
                return x / zeros * zeros;
        }
        else static if (m == HALF_EVEN)
        {
            const down = x / zeros;
            if (down % 2 == 0)
                return down * zeros;
            else
                return (down + 1) * zeros;
        }
        else static if (m == HALF_ODD)
        {
            const down = x / zeros;
            if (down % 2 == 0)
                return (down + 1) * zeros;
            else
                return down * zeros;
        }
        else static if (m == HALF_TO_ZERO)
        {
            const down = x / zeros;
            if (down < 0)
            {
                if (abs(x % zeros) <= half)
                {
                    return (down) * zeros;
                }
                else
                {
                    return (down - 1) * zeros;
                }
            }
            else
            {
                if ((x % zeros) > half)
                {
                    return (down + 1) * zeros;
                }
                else
                {
                    return (down) * zeros;
                }
            }
        }
        else static if (m == HALF_FROM_ZERO)
        {
            const down = x / zeros;
            if (down < 0)
            {
                if (abs(x % zeros) < half)
                {
                    return (down) * zeros;
                }
                else
                {
                    return (down - 1) * zeros;
                }
            }
            else
            {
                if (x % zeros >= half)
                {
                    return (down + 1) * zeros;
                }
                else
                {
                    return (down) * zeros;
                }
            }
        }
        else static if (m == UNNECESSARY)
        {
            throw new ForbiddenRounding();
        }
    }
}

// dfmt off
///
unittest
{
    assert (round!(roundingMode.DOWN)     (1009, 1) == 1000);
    assert (round!(roundingMode.UP)       (1001, 1) == 1010);
    assert (round!(roundingMode.HALF_UP)  (1005, 1) == 1010);
    assert (round!(roundingMode.HALF_DOWN)(1005, 1) == 1000);
}
// dfmt on

@safe pure @nogc nothrow unittest
{
    // dfmt off
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
    // dfmt on
}

unittest
{
    import std.exception : assertThrown;

    assert(round!(roundingMode.UNNECESSARY)(10, 1) == 10);
    assertThrown!ForbiddenRounding(round!(roundingMode.UNNECESSARY)(12, 1) == 10);
}

/** Round a float to an integer according to rounding mode */
//pure nothrow @nogc @trusted
real round(real x, roundingMode m) body
{
    FloatingPointControl fpctrl;
    final switch (m) with (roundingMode)
    {
    case UP:
        return ceil(x);
    case DOWN:
        return floor(x);
    case HALF_UP:
        return lrint(x);
    case HALF_DOWN:
        fpctrl.rounding = FloatingPointControl.roundDown;
        return lrint(x);
    case HALF_TO_ZERO:
        fpctrl.rounding = FloatingPointControl.roundToZero;
        return lrint(x);
    case HALF_EVEN:
    case HALF_ODD:
    case HALF_FROM_ZERO:
    case UNNECESSARY:
        throw new ForbiddenRounding();
    }
}

unittest {
    assert(round(3.5, roundingMode.HALF_DOWN) == 3.0);
    assert(round(3.8, roundingMode.HALF_TO_ZERO) == 3.0);

    import std.exception : assertThrown;
    assertThrown!ForbiddenRounding(round(3.1, roundingMode.UNNECESSARY));
    assertThrown!ForbiddenRounding(round(3.1, roundingMode.HALF_EVEN));
    assertThrown!ForbiddenRounding(round(3.1, roundingMode.HALF_ODD));
    assertThrown!ForbiddenRounding(round(3.1, roundingMode.HALF_FROM_ZERO));
}

/** Exception is thrown if rounding would have to happen,
    but roundingMode.UNNECESSARY is specified. */
class ForbiddenRounding : Exception
{
    public
    {
        @safe pure nothrow this(string file = __FILE__, size_t line = __LINE__, Throwable next = null)
        {
            super("Rounding is forbidden", file, line, next);
        }
    }
}

/** Overflow would happen with money arithmetic. */
class OverflowException : Exception
{
    public
    {
        @safe pure nothrow this(string file = __FILE__, size_t line = __LINE__, Throwable next = null)
        {
            super("Overflow", file, line, next);
        }
    }
}
