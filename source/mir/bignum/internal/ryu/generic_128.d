// Converted and then optimised from generic_128.h and generic_128.c
// Copyright 2018 Ulf Adams (original code https://github.com/ulfjack/ryu)
// Copyright 2020 Ilya Yaroshenko (2020 D conversion and optimisation)
// License: $(HTTP www.apache.org/licenses/LICENSE-2.0, Apache-2.0)

// This is a generic 128-bit implementation of float to shortest conversion
// using the Ryu algorithm. It can handle any IEEE-compatible floating-point
// type up to 128 bits. In order to use this correctly, you must use the
// appropriate *_to_fd128 function for the underlying type - DO NOT CAST your
// input to another floating-point type, doing so will result in incorrect
// output!
//
// For any floating-point type that is not natively defined by the compiler,
// you can use genericBinaryToDecimal to work directly on the underlying bit
// representation.

module mir.bignum.internal.ryu.generic_128;

version(BigEndian)
    static assert (0, "Let us know if you are using Mir on BigEndian target and we will add support for this module.");

debug(ryu) import core.stdc.stdio;

import mir.bignum.decimal: Decimal;
import mir.bignum.fixed: UInt, extendedMulHigh, extendedMul;

@safe pure nothrow @nogc:

// Returns e == 0 ? 1 : ceil(log_2(5^e)); requires 0 <= e <= 32768.
uint pow5bits(const int e)
{
    version(LDC) pragma(inline, true);
    assert(e >= 0);
    assert(e <= 1 << 15);
    return cast(uint) (((e * 163391164108059UL) >> 46) + 1);
}

void mul_128_256_shift(const UInt!128 a, const UInt!256 b, const uint shift, const uint corr, ref UInt!256 result)
{
    version(LDC) pragma(inline, true);
    assert(shift > 0);
    assert(shift < 256);
    result = (extendedMul(a, b) >> shift).toSize!256 + corr;
}

// Computes 5^i in the form required by Ryu, and stores it in the given pointer.
void generic_computePow5(const uint i, ref UInt!256 result)
{
    version(LDC) pragma(inline, true);
    const uint base = i / POW5_TABLE_SIZE;
    const uint base2 = base * POW5_TABLE_SIZE;
    const mul = UInt!256(GENERIC_POW5_SPLIT[base]);
    if (i == base2)
    {
        result = mul;
    }
    else
    {
        const uint offset = i - base2;
        const m = UInt!128(GENERIC_POW5_TABLE[offset]);
        const uint delta = pow5bits(i) - pow5bits(base2);
        const uint corr = cast(uint) ((POW5_ERRORS[i / 32] >> (2 * (i % 32))) & 3);
        mul_128_256_shift(m, mul, delta, corr, result);
    }
}

version(mir_bignum_test) unittest
{
    // We only test a few entries - we could test the fUL table instead, but should we?
    static immutable uint[10] EXACT_POW5_IDS = [1, 10, 55, 56, 300, 1000, 2345, 3210, 4968 - 3, 4968 - 1];

    static immutable ulong[4][10] EXACT_POW5 = [
        [                   0u,                    0u,                    0u,  90071992547409920u],
        [                   0u,                    0u,                    0u,  83886080000000000u],
        [                   0u, 15708555500268290048u, 14699724349295723422u, 117549435082228750u],
        [                   0u,  5206161169240293376u,  4575641699882439235u,  73468396926392969u],
        [ 2042133660145364371u,  9702060195405861314u,  6467325284806654637u, 107597969523956154u],
        [15128847313296546509u, 11916317791371073891u,   788593023170869613u, 137108429762886488u],
        [10998857860460266920u,   858411415306315808u, 12732466392391605111u, 136471991906002539u],
        [ 5404652432687674341u, 18039986361557197657u,  2228774284272261859u,  94370442653226447u],
        [15313487127299642753u,  9780770376910163681u, 15213531439620567348u,  93317108016191349u],
        [ 7928436552078881485u,   723697829319983520u,   932817143438521969u,  72903990637649492u],
    ];

    for (int i = 0; i < 10; i++)
    {
        UInt!256 result;
        generic_computePow5(EXACT_POW5_IDS[i], result);
        assert(UInt!256(EXACT_POW5[i]) == result);
    }
}

// Computes 5^-i in the form required by Ryu, and stores it in the given pointer.
void generic_computeInvPow5(const uint i, ref UInt!256 result)
{
    version(LDC) pragma(inline, true);
    const uint base = (i + POW5_TABLE_SIZE - 1) / POW5_TABLE_SIZE;
    const uint base2 = base * POW5_TABLE_SIZE;
    const mul = UInt!256(GENERIC_POW5_INV_SPLIT[base]); // 1/5^base2
    if (i == base2)
    {
        result = mul + 1;
    }
    else
    {
        const uint offset = base2 - i;
        const m = UInt!128(GENERIC_POW5_TABLE[offset]); // 5^offset
        const uint delta = pow5bits(base2) - pow5bits(i);
        const uint corr = cast(uint) ((POW5_INV_ERRORS[i / 32] >> (2 * (i % 32))) & 3) + 1;
        mul_128_256_shift(m, mul, delta, corr, result);
    }
}

version(mir_bignum_test) unittest
{
    static immutable uint[9] EXACT_INV_POW5_IDS = [10, 55, 56, 300, 1000, 2345, 3210, 4897 - 3, 4897 - 1];

    static immutable ulong[4][10] EXACT_INV_POW5 = [
        [13362655651931650467u,  3917988799323120213u,  9037289074543890586u, 123794003928538027u],
        [  983662216614650042u, 15516934687640009097u,  8839031818921249472u,  88342353238919216u],
        [ 1573859546583440066u,  2691002611772552616u,  6763753280790178510u, 141347765182270746u],
        [ 1607391579053635167u,   943946735193622172u, 10726301928680150504u,  96512915280967053u],
        [ 7238603269427345471u, 17319296798264127544u, 14852913523241959878u,  75740009093741608u],
        [ 2734564866961569744u, 13277212449690943834u, 17231454566843360565u,  76093223027199785u],
        [ 5348945211244460332u, 14119936934335594321u, 15647307321253222579u, 110040743956546595u],
        [ 2848579222248330872u, 15087265905644220040u,  4449739884766224405u, 100774177495370196u],
        [ 1432572115632717323u,  9719393440895634811u,  3482057763655621045u, 128990947194073851u],
    ];

    for (int i = 0; i < 9; i++)
    {
        UInt!256 result;
        generic_computeInvPow5(EXACT_INV_POW5_IDS[i], result);
        assert(UInt!256(EXACT_INV_POW5[i]) == result);
    }
}

version(LittleEndian)
    enum fiveReciprocal = UInt!128([0xCCCCCCCCCCCCCCCD, 0xCCCCCCCCCCCCCCCC]);
else
    enum fiveReciprocal = UInt!128([0xCCCCCCCCCCCCCCCC, 0xCCCCCCCCCCCCCCCD]);

enum baseDiv5 = UInt!128([0x3333333333333333, 0x3333333333333333]);

uint divRem5(uint size)(ref UInt!size value)
{
    auto q = div5(value);
    auto r = cast(uint)(value - q * 5);
    value = q;
    return r;
}

uint divRem10(uint size)(ref UInt!size value)
{
    auto q = div10(value);
    auto r = cast(uint)(value - q * 10);
    value = q;
    return r;
}

uint rem5(uint size)(UInt!size value)
{
    return divRem5(value);
}

uint rem10(uint size)(UInt!size value)
{
    return divRem10(value);
}

UInt!size div5(uint size)(UInt!size value)
{
    return extendedMulHigh(value, fiveReciprocal.toSize!size) >> 2;
}

UInt!size div10(uint size)(UInt!size value)
{
    return extendedMulHigh(value, fiveReciprocal.toSize!size) >> 3;
}

// Returns true if value is divisible by 5^p.
bool multipleOfPowerOf5(uint size)(UInt!size value, const uint p)
{
    enum fiveReciprocal = .fiveReciprocal.toSize!size;
    enum baseDiv5 = .baseDiv5.toSize!size;
    version(LDC) pragma(inline, true);
    assert(value);
    for (uint count = 0;; ++count)
    {
        value *= fiveReciprocal;
        if (value > baseDiv5)
            return count >= p;
    }
}

version(mir_bignum_test) unittest
{
    assert(multipleOfPowerOf5(UInt!128(1), 0) == true);
    assert(multipleOfPowerOf5(UInt!128(1), 1) == false);
    assert(multipleOfPowerOf5(UInt!128(5), 1) == true);
    assert(multipleOfPowerOf5(UInt!128(25), 2) == true);
    assert(multipleOfPowerOf5(UInt!128(75), 2) == true);
    assert(multipleOfPowerOf5(UInt!128(50), 2) == true);
    assert(multipleOfPowerOf5(UInt!128(51), 2) == false);
    assert(multipleOfPowerOf5(UInt!128(75), 4) == false);
}

// Returns true if value is divisible by 2^p.
bool multipleOfPowerOf2(uint size)(const UInt!size value, const uint p)
{
    version(LDC) pragma(inline, true);
    return (value & ((UInt!size(1) << p) - 1)) == 0;
}

version(mir_bignum_test) unittest
{
    assert(multipleOfPowerOf5(UInt!128(1), 0) == true);
    assert(multipleOfPowerOf5(UInt!128(1), 1) == false);
    assert(multipleOfPowerOf2(UInt!128(2), 1) == true);
    assert(multipleOfPowerOf2(UInt!128(4), 2) == true);
    assert(multipleOfPowerOf2(UInt!128(8), 2) == true);
    assert(multipleOfPowerOf2(UInt!128(12), 2) == true);
    assert(multipleOfPowerOf2(UInt!128(13), 2) == false);
    assert(multipleOfPowerOf2(UInt!128(8), 4) == false);
}

UInt!size mulShift(uint size)(const UInt!size m, const UInt!256 mul, const uint j)
{
    version(LDC) pragma(inline, true);
    assert(j > 128);
    return (extendedMul(mul, m) >> 128 >> (j - 128)).toSize!size;
}

version(mir_bignum_test) unittest
{
    UInt!256 m = cast(ulong[4])[0, 0, 2, 0];
    assert(mulShift(UInt!128(1), m, 129) == 1u);
    assert(mulShift(UInt!128(12345), m, 129) == 12345u);
}

version(mir_bignum_test) unittest
{
    UInt!256 m = cast(ulong[4])[0, 0, 8, 0];
    UInt!128 f = (UInt!128(123) << 64) | 321;
    assert(mulShift(f, m, 131) == f);
}

// Returns floor(log_10(2^e)).
uint log10Pow2(const int e)
{
    version(LDC) pragma(inline, true);
    // The first value this approximation fails for is 2^1651 which is just greater than 10^297.
    assert(e >= 0);
    assert(e <= 1 << 15);
    return (e * 0x9A209A84FBCFUL) >> 49;
}

version(mir_bignum_test) unittest
{
    assert(log10Pow2(1) == 0u);
    assert(log10Pow2(5) == 1u);
    assert(log10Pow2(1 << 15) == 9864u);
}

// Returns floor(log_10(5^e)).
uint log10Pow5(const int e)
{
    version(LDC) pragma(inline, true);
    // The first value this approximation fails for is 5^2621 which is just greater than 10^1832.
    assert(e >= 0);
    assert(e <= 1 << 15);
    return (e * 0xB2EFB2BD8218UL) >> 48;
}

version(mir_bignum_test) unittest
{
    assert(log10Pow5(1) == 0u);
    assert(log10Pow5(2) == 1u);
    assert(log10Pow5(3) == 2u);
    assert(log10Pow5(1 << 15) == 22903u);
}

debug(ryu)
private char* s(UInt!128 v)
{
    import mir.conv: to;
    return (v.to!string ~ "\0").ptr;
}

// Converts the given binary floating point number to the shortest decimal floating point number
// that still accurately represents it.
Decimal!(T.mant_dig < 64 ? 1 : 2) genericBinaryToDecimal(T)(const T x)
{
    import mir.utility: _expect;
    import mir.math: signbit, fabs;
    enum coefficientSize = T.mant_dig <= 64 ? 64 : 128;
    enum workSize = T.mant_dig < 64 ? 64 : 128;
    enum wordCount = workSize / 64;

    Decimal!wordCount fd;
    if (_expect(x != x, false))
    {
        fd.coefficient = 1u;
        fd.exponent = fd.exponent.max;
    }
    else
    if (_expect(x.fabs == T.infinity, false))
    {
        fd.exponent = fd.exponent.max;
    }
    else
    if (x)
    {
        import mir.bignum.fp: Fp;
        const fp = Fp!coefficientSize(x, false);
        int e2 = cast(int) fp.exponent - 2;
        UInt!workSize m2 = fp.coefficient;

        const bool even = (fp.coefficient & 1) == 0;
        const bool acceptBounds = even;

        debug(ryu) if (!__ctfe)
        {
            printf("-> %s %s * 2^%d\n", (fp.sign ? "-" : "+").ptr, s(m2), e2 + 2);
        }

        // Step 2: Determine the interval of legal decimal representations.
        const UInt!workSize mv = m2 << 2;
        // Implicit bool -> int conversion. True is 1, false is 0.
        const bool mmShift = fp.coefficient != (UInt!coefficientSize(1) << (T.mant_dig - 1));

        // Step 3: Convert to a decimal power base using 128-bit arithmetic.
        UInt!workSize vr, vp, vm;
        int e10;
        bool vmIsTrailingZeros = false;
        bool vrIsTrailingZeros = false;
        if (e2 >= 0)
        {
            // I tried special-casing q == 0, but there was no effect on performance.
            // This expression is slightly faster than max(0, log10Pow2(e2) - 1).
            const uint q = log10Pow2(e2) - (e2 > 3);
            e10 = q;
            const int k = FLOAT_128_POW5_INV_BITCOUNT + pow5bits(q) - 1;
            const int i = -e2 + q + k;
            UInt!256 pow5;
            generic_computeInvPow5(q, pow5);
            vr = mulShift(mv, pow5, i);
            vp = mulShift(mv + 2, pow5, i);
            vm = mulShift(mv - 1 - mmShift, pow5, i);
            debug(ryu) if (!__ctfe)
            {
                printf("%s * 2^%d / 10^%d\n", s(mv), e2, q);
                printf("V+=%s\nV =%s\nV-=%s\n", s(vp), s(vr), s(vm));
            }
            // floor(log_5(2^128)) = 55, this is very conservative
            if (q <= 55)
            {
                // Only one of mp, mv, and mm can be a multiple of 5, if any.
                if (rem5(mv) == 0)
                {
                    vrIsTrailingZeros = multipleOfPowerOf5(mv, q - 1);
                }
                else
                if (acceptBounds)
                {
                    // Same as min(e2 + (~mm & 1), pow5Factor(mm)) >= q
                    // <=> e2 + (~mm & 1) >= q && pow5Factor(mm) >= q
                    // <=> true && pow5Factor(mm) >= q, since e2 >= q.
                    vmIsTrailingZeros = multipleOfPowerOf5(mv - 1 - mmShift, q);
                }
                else
                {
                    // Same as min(e2 + 1, pow5Factor(mp)) >= q.
                    vp -= multipleOfPowerOf5(mv + 2, q);
                }
            }
        }
        else
        {
            // This expression is slightly faster than max(0, log10Pow5(-e2) - 1).
            const uint q = log10Pow5(-e2) - (-e2 > 1);
            e10 = q + e2;
            const int i = -e2 - q;
            const int k = pow5bits(i) - FLOAT_128_POW5_BITCOUNT;
            const int j = q - k;
            UInt!256 pow5;
            generic_computePow5(i, pow5);
            vr = mulShift(mv, pow5, j);
            vp = mulShift(mv + 2, pow5, j);
            vm = mulShift(mv - 1 - mmShift, pow5, j);
            debug(ryu) if (!__ctfe)
            {
                printf("%s * 5^%d / 10^%d\n", s(mv), -e2, q);
                printf("%d %d %d %d\n", q, i, k, j);
                printf("V+=%s\nV =%s\nV-=%s\n", s(vp), s(vr), s(vm));
            }
            if (q <= 1)
            {
                // {vr,vp,vm} is trailing zeros if {mv,mp,mm} has at least q trailing 0 bits.
                // mv = 4 m2, so it always has at least two trailing 0 bits.
                vrIsTrailingZeros = true;
                if (acceptBounds)
                {
                    // mm = mv - 1 - mmShift, so it has 1 trailing 0 bit iff mmShift == 1.
                    vmIsTrailingZeros = mmShift == 1;
                }
                else
                {
                    // mp = mv + 2, so it always has at least one trailing 0 bit.
                    --vp;
                }
            }
            else
            if (q < workSize - 1)
            {
                // TODO(ulfjack): Use a tighter bound here.
                // We need to compute min(ntz(mv), pow5Factor(mv) - e2) >= q-1
                // <=> ntz(mv) >= q-1  &&  pow5Factor(mv) - e2 >= q-1
                // <=> ntz(mv) >= q-1    (e2 is negative and -e2 >= q)
                // <=> (mv & ((1 << (q-1)) - 1)) == 0
                // We also need to make sure that the left shift does not overflow.
                vrIsTrailingZeros = multipleOfPowerOf2(mv, q - 1);
                debug(ryu) if (!__ctfe)
                {
                    printf("vr is trailing zeros=%s\n", (vrIsTrailingZeros ? "true" : "false").ptr);
                }
            }
        }
        debug(ryu) if (!__ctfe)
        {
            printf("e10=%d\n", e10);
            printf("V+=%s\nV =%s\nV-=%s\n", s(vp), s(vr), s(vm));
            printf("vm is trailing zeros=%s\n", (vmIsTrailingZeros ? "true" : "false").ptr);
            printf("vr is trailing zeros=%s\n", (vrIsTrailingZeros ? "true" : "false").ptr);
        }

        // Step 4: Find the shortest decimal representation in the interval of legal representations.
        uint removed = 0;
        uint lastRemovedDigit = 0;
        UInt!workSize output;

        for (;;)
        {
            auto div10vp = div10(vp);
            auto div10vm = div10(vm);
            if (div10vp == div10vm)
                break;
            vmIsTrailingZeros &= vm - div10vm * 10 == 0;
            vrIsTrailingZeros &= lastRemovedDigit == 0;
            lastRemovedDigit = vr.divRem10;
            vp = div10vp;
            vm = div10vm;
            ++removed;
        }
        debug(ryu) if (!__ctfe)
        {
            printf("V+=%s\nV =%s\nV-=%s\n", s(vp), s(vr), s(vm));
            printf("d-10=%s\n", (vmIsTrailingZeros ? "true" : "false").ptr);
            printf("lastRemovedDigit=%d\n", lastRemovedDigit);
        }
        if (vmIsTrailingZeros)
        {
            for (;;)
            {
                auto div10vm = div10(vm);
                if (vm - div10vm * 10)
                    break;
                vrIsTrailingZeros &= lastRemovedDigit == 0;
                lastRemovedDigit = cast(uint) (vr - div10vm * 10);
                vr = vp = vm = div10vm;
                ++removed;
            }
        }
        debug(ryu) if (!__ctfe)
        {
            printf("%s %d\n", s(vr), lastRemovedDigit);
            printf("vr is trailing zeros=%s\n", (vrIsTrailingZeros ? "true" : "false").ptr);
            printf("lastRemovedDigit=%d\n", lastRemovedDigit);
        }
        if (vrIsTrailingZeros && (lastRemovedDigit == 5) && ((vr & 1) == 0))
        {
            // Round even if the exact numbers is .....50..0.
            lastRemovedDigit = 4;
        }
        // We need to take vr+1 if vr is outside bounds or we need to round up.
        output = vr + ((vr == vm && (!acceptBounds || !vmIsTrailingZeros)) || (lastRemovedDigit >= 5));

        const int exp = e10 + removed;

        debug(ryu) if (!__ctfe)
        {
            printf("V+=%s\nV =%s\nV-=%s\n", s(vp), s(vr), s(vm));
            printf("acceptBounds=%d\n", acceptBounds);
            printf("vmIsTrailingZeros=%d\n", vmIsTrailingZeros);
            printf("lastRemovedDigit=%d\n", lastRemovedDigit);
            printf("vrIsTrailingZeros=%d\n", vrIsTrailingZeros);
            printf("O=%s\n", s(output));
            printf("EXP=%d\n", exp);
        }

        import mir.bignum.integer: BigInt;
        fd.coefficient.__ctor(output);
        fd.exponent = exp;
    }
    fd.coefficient.sign = x.signbit;
    return fd;
}

private enum FLOAT_128_POW5_INV_BITCOUNT = 249;
private enum FLOAT_128_POW5_BITCOUNT = 249;
private enum POW5_TABLE_SIZE = 56;

// These tables are ~4.5 kByte total, compared to ~160 kByte for the fUL tables.

// There's no way to define 128-bit constants in C, so we use little-endian
// pairs of 64-bit constants.
private static immutable ulong[2] [POW5_TABLE_SIZE] GENERIC_POW5_TABLE = [
    [                   1u,                    0u],
    [                   5u,                    0u],
    [                  25u,                    0u],
    [                 125u,                    0u],
    [                 625u,                    0u],
    [                3125u,                    0u],
    [               15625u,                    0u],
    [               78125u,                    0u],
    [              390625u,                    0u],
    [             1953125u,                    0u],
    [             9765625u,                    0u],
    [            48828125u,                    0u],
    [           244140625u,                    0u],
    [          1220703125u,                    0u],
    [          6103515625u,                    0u],
    [         30517578125u,                    0u],
    [        152587890625u,                    0u],
    [        762939453125u,                    0u],
    [       3814697265625u,                    0u],
    [      19073486328125u,                    0u],
    [      95367431640625u,                    0u],
    [     476837158203125u,                    0u],
    [    2384185791015625u,                    0u],
    [   11920928955078125u,                    0u],
    [   59604644775390625u,                    0u],
    [  298023223876953125u,                    0u],
    [ 1490116119384765625u,                    0u],
    [ 7450580596923828125u,                    0u],
    [  359414837200037393u,                    2u],
    [ 1797074186000186965u,                   10u],
    [ 8985370930000934825u,                   50u],
    [ 8033366502585570893u,                  252u],
    [ 3273344365508751233u,                 1262u],
    [16366721827543756165u,                 6310u],
    [ 8046632842880574361u,                31554u],
    [ 3339676066983768573u,               157772u],
    [16698380334918842865u,               788860u],
    [ 9704925379756007861u,              3944304u],
    [11631138751360936073u,             19721522u],
    [ 2815461535676025517u,             98607613u],
    [14077307678380127585u,            493038065u],
    [15046306170771983077u,           2465190328u],
    [ 1444554559021708921u,          12325951644u],
    [ 7222772795108544605u,          61629758220u],
    [17667119901833171409u,         308148791101u],
    [14548623214327650581u,        1540743955509u],
    [17402883850509598057u,        7703719777548u],
    [13227442957709783821u,       38518598887744u],
    [10796982567420264257u,      192592994438723u],
    [17091424689682218053u,      962964972193617u],
    [11670147153572883801u,     4814824860968089u],
    [ 3010503546735764157u,    24074124304840448u],
    [15052517733678820785u,   120370621524202240u],
    [ 1475612373555897461u,   601853107621011204u],
    [ 7378061867779487305u,  3009265538105056020u],
    [18443565265187884909u, 15046327690525280101u],
];

private static immutable ulong[4][89] GENERIC_POW5_SPLIT = [
    [                    0u,                    0u,                    0u,    72057594037927936u],
    [                    0u,  5206161169240293376u,  4575641699882439235u,    73468396926392969u],
    [  3360510775605221349u,  6983200512169538081u,  4325643253124434363u,    74906821675075173u],
    [ 11917660854915489451u,  9652941469841108803u,   946308467778435600u,    76373409087490117u],
    [  1994853395185689235u, 16102657350889591545u,  6847013871814915412u,    77868710555449746u],
    [   958415760277438274u, 15059347134713823592u,  7329070255463483331u,    79393288266368765u],
    [  2065144883315240188u,  7145278325844925976u, 14718454754511147343u,    80947715414629833u],
    [  8980391188862868935u, 13709057401304208685u,  8230434828742694591u,    82532576417087045u],
    [   432148644612782575u,  7960151582448466064u, 12056089168559840552u,    84148467132788711u],
    [   484109300864744403u, 15010663910730448582u, 16824949663447227068u,    85795995087002057u],
    [ 14793711725276144220u, 16494403799991899904u, 10145107106505865967u,    87475779699624060u],
    [ 15427548291869817042u, 12330588654550505203u, 13980791795114552342u,    89188452518064298u],
    [  9979404135116626552u, 13477446383271537499u, 14459862802511591337u,    90934657454687378u],
    [ 12385121150303452775u,  9097130814231585614u,  6523855782339765207u,    92715051028904201u],
    [  1822931022538209743u, 16062974719797586441u,  3619180286173516788u,    94530302614003091u],
    [ 12318611738248470829u, 13330752208259324507u, 10986694768744162601u,    96381094688813589u],
    [ 13684493829640282333u,  7674802078297225834u, 15208116197624593182u,    98268123094297527u],
    [  5408877057066295332u,  6470124174091971006u, 15112713923117703147u,   100192097295163851u],
    [ 11407083166564425062u, 18189998238742408185u,  4337638702446708282u,   102153740646605557u],
    [  4112405898036935485u,   924624216579956435u, 14251108172073737125u,   104153790666259019u],
    [ 16996739107011444789u, 10015944118339042475u,  2395188869672266257u,   106192999311487969u],
    [  4588314690421337879u,  5339991768263654604u, 15441007590670620066u,   108272133262096356u],
    [  2286159977890359825u, 14329706763185060248u,  5980012964059367667u,   110391974208576409u],
    [  9654767503237031099u, 11293544302844823188u, 11739932712678287805u,   112553319146000238u],
    [ 11362964448496095896u,  7990659682315657680u,   251480263940996374u,   114756980673665505u],
    [  1423410421096377129u, 14274395557581462179u, 16553482793602208894u,   117003787300607788u],
    [  2070444190619093137u, 11517140404712147401u, 11657844572835578076u,   119294583757094535u],
    [  7648316884775828921u, 15264332483297977688u,   247182277434709002u,   121630231312217685u],
    [ 17410896758132241352u, 10923914482914417070u, 13976383996795783649u,   124011608097704390u],
    [  9542674537907272703u,  3079432708831728956u, 14235189590642919676u,   126439609438067572u],
    [ 10364666969937261816u,  8464573184892924210u, 12758646866025101190u,   128915148187220428u],
    [ 14720354822146013883u, 11480204489231511423u,  7449876034836187038u,   131439155071681461u],
    [  1692907053653558553u, 17835392458598425233u,  1754856712536736598u,   134012579040499057u],
    [  5620591334531458755u, 11361776175667106627u, 13350215315297937856u,   136636387622027174u],
    [ 17455759733928092601u, 10362573084069962561u, 11246018728801810510u,   139311567287686283u],
    [  2465404073814044982u, 17694822665274381860u,  1509954037718722697u,   142039123822846312u],
    [  2152236053329638369u, 11202280800589637091u, 16388426812920420176u,    72410041352485523u],
    [ 17319024055671609028u, 10944982848661280484u,  2457150158022562661u,    73827744744583080u],
    [ 17511219308535248024u,  5122059497846768077u,  2089605804219668451u,    75273205100637900u],
    [ 10082673333144031533u, 14429008783411894887u, 12842832230171903890u,    76746965869337783u],
    [ 16196653406315961184u, 10260180891682904501u, 10537411930446752461u,    78249581139456266u],
    [ 15084422041749743389u,   234835370106753111u, 16662517110286225617u,    79781615848172976u],
    [  8199644021067702606u,  3787318116274991885u,  7438130039325743106u,    81343645993472659u],
    [ 12039493937039359765u,  9773822153580393709u,  5945428874398357806u,    82936258850702722u],
    [   984543865091303961u,  7975107621689454830u,  6556665988501773347u,    84560053193370726u],
    [  9633317878125234244u, 16099592426808915028u,  9706674539190598200u,    86215639518264828u],
    [  6860695058870476186u,  4471839111886709592u,  7828342285492709568u,    87903640274981819u],
    [ 14583324717644598331u,  4496120889473451238u,  5290040788305728466u,    89624690099949049u],
    [ 18093669366515003715u, 12879506572606942994u, 18005739787089675377u,    91379436055028227u],
    [ 17997493966862379937u, 14646222655265145582u, 10265023312844161858u,    93168537870790806u],
    [ 12283848109039722318u, 11290258077250314935u,  9878160025624946825u,    94992668194556404u],
    [  8087752761883078164u,  5262596608437575693u, 11093553063763274413u,    96852512843287537u],
    [ 15027787746776840781u, 12250273651168257752u,  9290470558712181914u,    98748771061435726u],
    [ 15003915578366724489u,  2937334162439764327u,  5404085603526796602u,   100682155783835929u],
    [  5225610465224746757u, 14932114897406142027u,  2774647558180708010u,   102653393903748137u],
    [ 17112957703385190360u, 12069082008339002412u,  3901112447086388439u,   104663226546146909u],
    [  4062324464323300238u,  3992768146772240329u, 15757196565593695724u,   106712409346361594u],
    [  5525364615810306701u, 11855206026704935156u, 11344868740897365300u,   108801712734172003u],
    [  9274143661888462646u,  4478365862348432381u, 18010077872551661771u,   110931922223466333u],
    [ 12604141221930060148u,  8930937759942591500u,  9382183116147201338u,   113103838707570263u],
    [ 14513929377491886653u,  1410646149696279084u,   587092196850797612u,   115318278760358235u],
    [  2226851524999454362u,  7717102471110805679u,  7187441550995571734u,   117576074943260147u],
    [  5527526061344932763u,  2347100676188369132u, 16976241418824030445u,   119878076118278875u],
    [  6088479778147221611u, 17669593130014777580u, 10991124207197663546u,   122225147767136307u],
    [ 11107734086759692041u,  3391795220306863431u, 17233960908859089158u,   124618172316667879u],
    [  7913172514655155198u, 17726879005381242552u,   641069866244011540u,   127058049470587962u],
    [ 12596991768458713949u, 15714785522479904446u,  6035972567136116512u,   129545696547750811u],
    [ 16901996933781815980u,  4275085211437148707u, 14091642539965169063u,   132082048827034281u],
    [  7524574627987869240u, 15661204384239316051u,  2444526454225712267u,   134668059898975949u],
    [  8199251625090479942u,  6803282222165044067u, 16064817666437851504u,   137304702024293857u],
    [  4453256673338111920u, 15269922543084434181u,  3139961729834750852u,   139992966499426682u],
    [ 15841763546372731299u,  3013174075437671812u,  4383755396295695606u,   142733864029230733u],
    [  9771896230907310329u,  4900659362437687569u, 12386126719044266361u,    72764212553486967u],
    [  9420455527449565190u,  1859606122611023693u,  6555040298902684281u,    74188850200884818u],
    [  5146105983135678095u,  2287300449992174951u,  4325371679080264751u,    75641380576797959u],
    [ 11019359372592553360u,  8422686425957443718u,  7175176077944048210u,    77122349788024458u],
    [ 11005742969399620716u,  4132174559240043701u,  9372258443096612118u,    78632314633490790u],
    [  8887589641394725840u,  8029899502466543662u, 14582206497241572853u,    80171842813591127u],
    [   360247523705545899u, 12568341805293354211u, 14653258284762517866u,    81741513143625247u],
    [ 12314272731984275834u,  4740745023227177044u,  6141631472368337539u,    83341915771415304u],
    [   441052047733984759u,  7940090120939869826u, 11750200619921094248u,    84973652399183278u],
    [  3436657868127012749u,  9187006432149937667u, 16389726097323041290u,    86637336509772529u],
    [ 13490220260784534044u, 15339072891382896702u,  8846102360835316895u,    88333593597298497u],
    [  4125672032094859833u,   158347675704003277u, 10592598512749774447u,    90063061402315272u],
    [ 12189928252974395775u,  2386931199439295891u,  7009030566469913276u,    91826390151586454u],
    [  9256479608339282969u,  2844900158963599229u, 11148388908923225596u,    93624242802550437u],
    [ 11584393507658707408u,  2863659090805147914u,  9873421561981063551u,    95457295292572042u],
    [ 13984297296943171390u,  1931468383973130608u, 12905719743235082319u,    97326236793074198u],
    [  5837045222254987499u, 10213498696735864176u, 14893951506257020749u,    99231769968645227u],
];

// Unfortunately, the results are sometimes off by one or two. We use an additional
// lookup table to store those cases and adjust the result.
private static immutable ulong[156] POW5_ERRORS = [
    0x0000000000000000u, 0x0000000000000000u, 0x0000000000000000u, 0x9555596400000000u,
    0x65a6569525565555u, 0x4415551445449655u, 0x5105015504144541u, 0x65a69969a6965964u,
    0x5054955969959656u, 0x5105154515554145u, 0x4055511051591555u, 0x5500514455550115u,
    0x0041140014145515u, 0x1005440545511051u, 0x0014405450411004u, 0x0414440010500000u,
    0x0044000440010040u, 0x5551155000004001u, 0x4554555454544114u, 0x5150045544005441u,
    0x0001111400054501u, 0x6550955555554554u, 0x1504159645559559u, 0x4105055141454545u,
    0x1411541410405454u, 0x0415555044545555u, 0x0014154115405550u, 0x1540055040411445u,
    0x0000000500000000u, 0x5644000000000000u, 0x1155555591596555u, 0x0410440054569565u,
    0x5145100010010005u, 0x0555041405500150u, 0x4141450455140450u, 0x0000000144000140u,
    0x5114004001105410u, 0x4444100404005504u, 0x0414014410001015u, 0x5145055155555015u,
    0x0141041444445540u, 0x0000100451541414u, 0x4105041104155550u, 0x0500501150451145u,
    0x1001050000004114u, 0x5551504400141045u, 0x5110545410151454u, 0x0100001400004040u,
    0x5040010111040000u, 0x0140000150541100u, 0x4400140400104110u, 0x5011014405545004u,
    0x0000000044155440u, 0x0000000010000000u, 0x1100401444440001u, 0x0040401010055111u,
    0x5155155551405454u, 0x0444440015514411u, 0x0054505054014101u, 0x0451015441115511u,
    0x1541411401140551u, 0x4155104514445110u, 0x4141145450145515u, 0x5451445055155050u,
    0x4400515554110054u, 0x5111145104501151u, 0x565a655455500501u, 0x5565555555525955u,
    0x0550511500405695u, 0x4415504051054544u, 0x6555595965555554u, 0x0100915915555655u,
    0x5540001510001001u, 0x5450051414000544u, 0x1405010555555551u, 0x5555515555644155u,
    0x5555055595496555u, 0x5451045004415000u, 0x5450510144040144u, 0x5554155555556455u,
    0x5051555495415555u, 0x5555554555555545u, 0x0000000010005455u, 0x4000005000040000u,
    0x5565555555555954u, 0x5554559555555505u, 0x9645545495552555u, 0x4000400055955564u,
    0x0040000000000001u, 0x4004100100000000u, 0x5540040440000411u, 0x4565555955545644u,
    0x1140659549651556u, 0x0100000410010000u, 0x5555515400004001u, 0x5955545555155255u,
    0x5151055545505556u, 0x5051454510554515u, 0x0501500050415554u, 0x5044154005441005u,
    0x1455445450550455u, 0x0010144055144545u, 0x0000401100000004u, 0x1050145050000010u,
    0x0415004554011540u, 0x1000510100151150u, 0x0100040400001144u, 0x0000000000000000u,
    0x0550004400000100u, 0x0151145041451151u, 0x0000400400005450u, 0x0000100044010004u,
    0x0100054100050040u, 0x0504400005410010u, 0x4011410445500105u, 0x0000404000144411u,
    0x0101504404500000u, 0x0000005044400400u, 0x0000000014000100u, 0x0404440414000000u,
    0x5554100410000140u, 0x4555455544505555u, 0x5454105055455455u, 0x0115454155454015u,
    0x4404110000045100u, 0x4400001100101501u, 0x6596955956966a94u, 0x0040655955665965u,
    0x5554144400100155u, 0xa549495401011041u, 0x5596555565955555u, 0x5569965959549555u,
    0x969565a655555456u, 0x0000001000000000u, 0x0000000040000140u, 0x0000040100000000u,
    0x1415454400000000u, 0x5410415411454114u, 0x0400040104000154u, 0x0504045000000411u,
    0x0000001000000010u, 0x5554000000001040u, 0x5549155551556595u, 0x1455541055515555u,
    0x0510555454554541u, 0x9555555555540455u, 0x6455456555556465u, 0x4524565555654514u,
    0x5554655255559545u, 0x9555455441155556u, 0x0000000051515555u, 0x0010005040000550u,
    0x5044044040000000u, 0x1045040440010500u, 0x0000400000040000u, 0x0000000000000000u,
];

private static immutable ulong[4][89] GENERIC_POW5_INV_SPLIT = [
    [                    0u,                    0u,                    0u,   144115188075855872u ],
    [  1573859546583440065u,  2691002611772552616u,  6763753280790178510u,   141347765182270746u ],
    [ 12960290449513840412u, 12345512957918226762u, 18057899791198622765u,   138633484706040742u ],
    [  7615871757716765416u,  9507132263365501332u,  4879801712092008245u,   135971326161092377u ],
    [  7869961150745287587u,  5804035291554591636u,  8883897266325833928u,   133360288657597085u ],
    [  2942118023529634767u, 15128191429820565086u, 10638459445243230718u,   130799390525667397u ],
    [ 14188759758411913794u,  5362791266439207815u,  8068821289119264054u,   128287668946279217u ],
    [  7183196927902545212u,  1952291723540117099u, 12075928209936341512u,   125824179589281448u ],
    [  5672588001402349748u, 17892323620748423487u,  9874578446960390364u,   123407996258356868u ],
    [  4442590541217566325u,  4558254706293456445u, 10343828952663182727u,   121038210542800766u ],
    [  3005560928406962566u,  2082271027139057888u, 13961184524927245081u,   118713931475986426u ],
    [ 13299058168408384786u, 17834349496131278595u,  9029906103900731664u,   116434285200389047u ],
    [  5414878118283973035u, 13079825470227392078u, 17897304791683760280u,   114198414639042157u ],
    [ 14609755883382484834u, 14991702445765844156u,  3269802549772755411u,   112005479173303009u ],
    [ 15967774957605076027u,  2511532636717499923u, 16221038267832563171u,   109854654326805788u ],
    [  9269330061621627145u,  3332501053426257392u, 16223281189403734630u,   107745131455483836u ],
    [ 16739559299223642282u,  1873986623300664530u,  6546709159471442872u,   105676117443544318u ],
    [ 17116435360051202055u,  1359075105581853924u,  2038341371621886470u,   103646834405281051u ],
    [ 17144715798009627550u,  3201623802661132408u,  9757551605154622431u,   101656519392613377u ],
    [ 17580479792687825857u,  6546633380567327312u, 15099972427870912398u,    99704424108241124u ],
    [  9726477118325522902u, 14578369026754005435u, 11728055595254428803u,    97789814624307808u ],
    [   134593949518343635u,  5715151379816901985u,  1660163707976377376u,    95911971106466306u ],
    [  5515914027713859358u,  7124354893273815720u,  5548463282858794077u,    94070187543243255u ],
    [  6188403395862945512u,  5681264392632320838u, 15417410852121406654u,    92263771480600430u ],
    [ 15908890877468271457u, 10398888261125597540u,  4817794962769172309u,    90492043761593298u ],
    [  1413077535082201005u, 12675058125384151580u,  7731426132303759597u,    88754338271028867u ],
    [  1486733163972670293u, 11369385300195092554u, 11610016711694864110u,    87050001685026843u ],
    [  8788596583757589684u,  3978580923851924802u,  9255162428306775812u,    85378393225389919u ],
    [  7203518319660962120u, 15044736224407683725u,  2488132019818199792u,    83738884418690858u ],
    [  4004175967662388707u, 18236988667757575407u, 15613100370957482671u,    82130858859985791u ],
    [ 18371903370586036463u,    53497579022921640u, 16465963977267203307u,    80553711981064899u ],
    [ 10170778323887491315u,  1999668801648976001u, 10209763593579456445u,    79006850823153334u ],
    [ 17108131712433974546u, 16825784443029944237u,  2078700786753338945u,    77489693813976938u ],
    [ 17221789422665858532u, 12145427517550446164u,  5391414622238668005u,    76001670549108934u ],
    [  4859588996898795878u,  1715798948121313204u,  3950858167455137171u,    74542221577515387u ],
    [ 13513469241795711526u,   631367850494860526u, 10517278915021816160u,    73110798191218799u ],
    [ 11757513142672073111u,  2581974932255022228u, 17498959383193606459u,   143413724438001539u ],
    [ 14524355192525042817u,  5640643347559376447u,  1309659274756813016u,   140659771648132296u ],
    [  2765095348461978538u, 11021111021896007722u,  3224303603779962366u,   137958702611185230u ],
    [ 12373410389187981037u, 13679193545685856195u, 11644609038462631561u,   135309501808182158u ],
    [ 12813176257562780151u,  3754199046160268020u,  9954691079802960722u,   132711173221007413u ],
    [ 17557452279667723458u,  3237799193992485824u, 17893947919029030695u,   130162739957935629u ],
    [ 14634200999559435155u,  4123869946105211004u,  6955301747350769239u,   127663243886350468u ],
    [  2185352760627740240u,  2864813346878886844u, 13049218671329690184u,   125211745272516185u ],
    [  6143438674322183002u, 10464733336980678750u,  6982925169933978309u,   122807322428266620u ],
    [  1099509117817174576u, 10202656147550524081u,   754997032816608484u,   120449071364478757u ],
    [  2410631293559367023u, 17407273750261453804u, 15307291918933463037u,   118136105451200587u ],
    [ 12224968375134586697u,  1664436604907828062u, 11506086230137787358u,   115867555084305488u ],
    [  3495926216898000888u, 18392536965197424288u, 10992889188570643156u,   113642567358547782u ],
    [  8744506286256259680u,  3966568369496879937u, 18342264969761820037u,   111460305746896569u ],
    [  7689600520560455039u,  5254331190877624630u,  9628558080573245556u,   109319949786027263u ],
    [ 11862637625618819436u,  3456120362318976488u, 14690471063106001082u,   107220694767852583u ],
    [  5697330450030126444u, 12424082405392918899u,   358204170751754904u,   105161751436977040u ],
    [ 11257457505097373622u, 15373192700214208870u,   671619062372033814u,   103142345693961148u ],
    [ 16850355018477166700u,  1913910419361963966u,  4550257919755970531u,   101161718304283822u ],
    [  9670835567561997011u, 10584031339132130638u,  3060560222974851757u,    99219124612893520u ],
    [  7698686577353054710u, 11689292838639130817u, 11806331021588878241u,    97313834264240819u ],
    [ 12233569599615692137u,  3347791226108469959u, 10333904326094451110u,    95445130927687169u ],
    [ 13049400362825383933u, 17142621313007799680u,  3790542585289224168u,    93612312028186576u ],
    [ 12430457242474442072u,  5625077542189557960u, 14765055286236672238u,    91814688482138969u ],
    [  4759444137752473128u,  2230562561567025078u,  4954443037339580076u,    90051584438315940u ],
    [  7246913525170274758u,  8910297835195760709u,  4015904029508858381u,    88322337023761438u ],
    [ 12854430245836432067u,  8135139748065431455u, 11548083631386317976u,    86626296094571907u ],
    [  4848827254502687803u,  4789491250196085625u,  3988192420450664125u,    84962823991462151u ],
    [  7435538409611286684u,   904061756819742353u, 14598026519493048444u,    83331295300025028u ],
    [ 11042616160352530997u,  8948390828345326218u, 10052651191118271927u,    81731096615594853u ],
    [ 11059348291563778943u, 11696515766184685544u,  3783210511290897367u,    80161626312626082u ],
    [  7020010856491885826u,  5025093219346041680u,  8960210401638911765u,    78622294318500592u ],
    [ 17732844474490699984u,  7820866704994446502u,  6088373186798844243u,    77112521891678506u ],
    [   688278527545590501u,  3045610706602776618u,  8684243536999567610u,    75631741404109150u ],
    [  2734573255120657297u,  3903146411440697663u,  9470794821691856713u,    74179396127820347u ],
    [ 15996457521023071259u,  4776627823451271680u, 12394856457265744744u,    72754940025605801u ],
    [ 13492065758834518331u,  7390517611012222399u,  1630485387832860230u,   142715675091463768u ],
    [ 13665021627282055864u,  9897834675523659302u, 17907668136755296849u,   139975126841173266u ],
    [  9603773719399446181u, 10771916301484339398u, 10672699855989487527u,   137287204938390542u ],
    [  3630218541553511265u,  8139010004241080614u,  2876479648932814543u,   134650898807055963u ],
    [  8318835909686377084u,  9525369258927993371u,  2796120270400437057u,   132065217277054270u ],
    [ 11190003059043290163u, 12424345635599592110u, 12539346395388933763u,   129529188211565064u ],
    [  8701968833973242276u,   820569587086330727u,  2315591597351480110u,   127041858141569228u ],
    [  5115113890115690487u, 16906305245394587826u,  9899749468931071388u,   124602291907373862u ],
    [ 15543535488939245974u, 10945189844466391399u,  3553863472349432246u,   122209572307020975u ],
    [  7709257252608325038u,  1191832167690640880u, 15077137020234258537u,   119862799751447719u ],
    [  7541333244210021737u,  9790054727902174575u,  5160944773155322014u,   117561091926268545u ],
    [ 12297384708782857832u,  1281328873123467374u,  4827925254630475769u,   115303583460052092u ],
    [ 13243237906232367265u, 15873887428139547641u,  3607993172301799599u,   113089425598968120u ],
    [ 11384616453739611114u, 15184114243769211033u, 13148448124803481057u,   110917785887682141u ],
    [ 17727970963596660683u,  1196965221832671990u, 14537830463956404138u,   108787847856377790u ],
    [ 17241367586707330931u,  8880584684128262874u, 11173506540726547818u,   106698810713789254u ],
    [  7184427196661305643u, 14332510582433188173u, 14230167953789677901u,   104649889046128358u ],
];

private static immutable ulong[154] POW5_INV_ERRORS = [
    0x1144155514145504u, 0x0000541555401141u, 0x0000000000000000u, 0x0154454000000000u,
    0x4114105515544440u, 0x0001001111500415u, 0x4041411410011000u, 0x5550114515155014u,
    0x1404100041554551u, 0x0515000450404410u, 0x5054544401140004u, 0x5155501005555105u,
    0x1144141000105515u, 0x0541500000500000u, 0x1104105540444140u, 0x4000015055514110u,
    0x0054010450004005u, 0x4155515404100005u, 0x5155145045155555u, 0x1511555515440558u,
    0x5558544555515555u, 0x0000000000000010u, 0x5004000000000050u, 0x1415510100000010u,
    0x4545555444514500u, 0x5155151555555551u, 0x1441540144044554u, 0x5150104045544400u,
    0x5450545401444040u, 0x5554455045501400u, 0x4655155555555145u, 0x1000010055455055u,
    0x1000004000055004u, 0x4455405104000005u, 0x4500114504150545u, 0x0000000014000000u,
    0x5450000000000000u, 0x5514551511445555u, 0x4111501040555451u, 0x4515445500054444u,
    0x5101500104100441u, 0x1545115155545055u, 0x0000000000000000u, 0x1554000000100000u,
    0x5555545595551555u, 0x5555051851455955u, 0x5555555555555559u, 0x0000400011001555u,
    0x0000004400040000u, 0x5455511555554554u, 0x5614555544115445u, 0x6455156145555155u,
    0x5455855455415455u, 0x5515555144555545u, 0x0114400000145155u, 0x0000051000450511u,
    0x4455154554445100u, 0x4554150141544455u, 0x65955555559a5965u, 0x5555555854559559u,
    0x9569654559616595u, 0x1040044040005565u, 0x1010010500011044u, 0x1554015545154540u,
    0x4440555401545441u, 0x1014441450550105u, 0x4545400410504145u, 0x5015111541040151u,
    0x5145051154000410u, 0x1040001044545044u, 0x4001400000151410u, 0x0540000044040000u,
    0x0510555454411544u, 0x0400054054141550u, 0x1001041145001100u, 0x0000000140000000u,
    0x0000000014100000u, 0x1544005454000140u, 0x4050055505445145u, 0x0011511104504155u,
    0x5505544415045055u, 0x1155154445515554u, 0x0000000000004555u, 0x0000000000000000u,
    0x5101010510400004u, 0x1514045044440400u, 0x5515519555515555u, 0x4554545441555545u,
    0x1551055955551515u, 0x0150000011505515u, 0x0044005040400000u, 0x0004001004010050u,
    0x0000051004450414u, 0x0114001101001144u, 0x0401000001000001u, 0x4500010001000401u,
    0x0004100000005000u, 0x0105000441101100u, 0x0455455550454540u, 0x5404050144105505u,
    0x4101510540555455u, 0x1055541411451555u, 0x5451445110115505u, 0x1154110010101545u,
    0x1145140450054055u, 0x5555565415551554u, 0x1550559555555555u, 0x5555541545045141u,
    0x4555455450500100u, 0x5510454545554555u, 0x1510140115045455u, 0x1001050040111510u,
    0x5555454555555504u, 0x9954155545515554u, 0x6596656555555555u, 0x0140410051555559u,
    0x0011104010001544u, 0x965669659a680501u, 0x5655a55955556955u, 0x4015111014404514u,
    0x1414155554505145u, 0x0540040011051404u, 0x1010000000015005u, 0x0010054050004410u,
    0x5041104014000100u, 0x4440010500100001u, 0x1155510504545554u, 0x0450151545115541u,
    0x4000100400110440u, 0x1004440010514440u, 0x0000115050450000u, 0x0545404455541500u,
    0x1051051555505101u, 0x5505144554544144u, 0x4550545555515550u, 0x0015400450045445u,
    0x4514155400554415u, 0x4555055051050151u, 0x1511441450001014u, 0x4544554510404414u,
    0x4115115545545450u, 0x5500541555551555u, 0x5550010544155015u, 0x0144414045545500u,
    0x4154050001050150u, 0x5550511111000145u, 0x1114504055000151u, 0x5104041101451040u,
    0x0010501401051441u, 0x0010501450504401u, 0x4554585440044444u, 0x5155555951450455u,
    0x0040000400105555u, 0x0000000000000001u,
];
