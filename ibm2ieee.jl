#define IBM32_SIGN ((npy_uint32)0x80000000U)
#define IBM32_EXPT ((npy_uint32)0x7f000000U)
#define IBM32_FRAC ((npy_uint32)0x00ffffffU)
#define IBM32_TOP  ((npy_uint32)0x00f00000U)
#define TIES_TO_EVEN_MASK32 ((npy_uint32)0xfffffffdU)

#define IBM64_SIGN ((npy_uint64)0x8000000000000000U)
#define IBM64_EXPT ((npy_uint64)0x7f00000000000000U)
#define IBM64_FRAC ((npy_uint64)0x00ffffffffffffffU)
#define IBM64_TOP  ((npy_uint64)0x00f0000000000000U)
#define TIES_TO_EVEN_MASK64 ((npy_uint64)0xfffffffffffffffdU)

/* Masks used for 3-bit and 32-bit rounded right-shifts of a 64-bit quantity.
   The masks comprise the parity bit and the trailing bits for the shift. */
#define TIES_TO_EVEN_RSHIFT3  ((npy_uint64)0x000000000000000bU)
#define TIES_TO_EVEN_RSHIFT32 ((npy_uint64)0x000000017fffffffU)

#define IEEE32_MAXEXP 254     /* Maximum biased exponent for finite values. */
#define IEEE32_INFINITY ((npy_uint32)0x7f800000U)

/* Constant used to count number of leading bits in a nonzero hex digit
   via `(BITCOUNT_MAGIC >> (hex_digit*2)) & 3U`. */
#define BITCOUNT_MAGIC ((npy_uint32)0x000055afU)


/* IBM single-precision bit pattern to IEEE single-precision bit pattern. */

static npy_uint32
ibm32ieee32(npy_uint32 ibm)
{
    /* Overflow and underflow possible; rounding can only happen
       in subnormal cases. */
    int ibm_expt, ieee_expt, leading_zeros;
    npy_uint32 ibm_frac, top_digit;
    npy_uint32 ieee_sign, ieee_frac;

    ieee_sign = ibm & IBM32_SIGN;
    ibm_frac = ibm & IBM32_FRAC;

    /* Quick return for zeros. */
    if (!ibm_frac) {
        return ieee_sign;
    }

    /* Reduce shift by 2 to get a binary exponent from the hex exponent. */
    ibm_expt = (int)((ibm & IBM32_EXPT) >> 22);

    /* Normalise significand, then count leading zeros in top hex digit. */
    top_digit = ibm_frac & IBM32_TOP;
    while (top_digit == 0) {
        ibm_frac <<= 4;
        ibm_expt -= 4;
        top_digit = ibm_frac & IBM32_TOP;
    }
    leading_zeros = (int)((BITCOUNT_MAGIC >> (top_digit >> 19)) & 3U);
    ibm_frac <<= leading_zeros;

    /* Adjust exponents for the differing biases of the formats: the IBM bias
       is 64 hex digits, or 256 bits. The IEEE bias is 127. The difference is
       -129; we get an extra -1 from the different significand representations
       (0.f for IBM versus 1.f for IEEE), and another -1 to compensate for an
       evil trick that saves an operation on the fast path: we don't remove the
       hidden 1-bit from the IEEE significand, so in the final addition that
       extra bit ends in incrementing the exponent by one. */
    ieee_expt = ibm_expt - 131 - leading_zeros;

    if (ieee_expt >= 0 && ieee_expt < IEEE32_MAXEXP) {
        /* normal case; no shift needed */
        ieee_frac = ibm_frac;
        return ieee_sign + ((npy_uint32)ieee_expt << 23) + ieee_frac;
    }
    else if (ieee_expt >= IEEE32_MAXEXP) {
        /* overflow */
        return ieee_sign + IEEE32_INFINITY;
    }
    else if (ieee_expt >= -32) {
        /* possible subnormal result; shift significand right by -ieee_expt
           bits, rounding the result with round-ties-to-even.

           The round-ties-to-even code deserves some explanation: out of the
           bits we're shifting out, let's call the most significant bit the
           "rounding bit", and the rest the "trailing bits". We'll call the
           least significant bit that *isn't* shifted out the "parity bit".
           So for an example 5-bit shift right, we'd label the bits as follows:

           Before the shift:

                   ...xxxprtttt
                              ^
              msb            lsb

           After the shift:

                        ...xxxp
                              ^
              msb            lsb

           with the result possibly incremented by one.

           For round-ties-to-even, we need to round up if both (a) the rounding
           bit is 1, and (b) either the parity bit is 1, or at least one of the
           trailing bits is 1. We construct a mask that has 1-bits in the
           parity bit position and trailing bit positions, and use that to
           check condition (b). So for example in the 5-bit shift right, the
           mask looks like this:

                   ...000101111 : mask
                   ...xxxprtttt : ibm_frac
                              ^
              msb            lsb

           We then shift right by (shift - 1), add 1 if (ibm & mask) is
           nonzero, and then do a final shift by one to get the rounded
           value. Note that this approach avoids the possibility of
           trying to shift a width-32 value by 32, which would give
           undefined behaviour (see C99 6.5.7p3).
         */
        npy_uint32 mask = ~(TIES_TO_EVEN_MASK32 << (-1 - ieee_expt));
        npy_uint32 round_up = (ibm_frac & mask) > 0U;
        ieee_frac = ((ibm_frac >> (-1 - ieee_expt)) + round_up) >> 1;
        return ieee_sign + ieee_frac;
    }
    else {
        /* underflow to zero */
        return ieee_sign;
    }
}


/* IBM double-precision bit pattern to IEEE single-precision bit pattern. */

static npy_uint32
ibm64ieee32(npy_uint64 ibm)
{
    /* Overflow and underflow possible; rounding can occur in both
       normal and subnormal cases. */
    int ibm_expt, ieee_expt, leading_zeros;
    npy_uint64 ibm_frac, top_digit;
    npy_uint32 ieee_sign, ieee_frac;

    ieee_sign = (ibm & IBM64_SIGN) >> 32;
    ibm_frac = ibm & IBM64_FRAC;

    /* Quick return for zeros. */
    if (!ibm_frac) {
        return ieee_sign;
    }

    /* Reduce shift by 2 to get a binary exponent from the hex exponent. */
    ibm_expt = (int)((ibm & IBM64_EXPT) >> 54);

    /* Normalise significand, then count leading zeros in top hex digit. */
    top_digit = ibm_frac & IBM64_TOP;
    while (top_digit == 0) {
        ibm_frac <<= 4;
        ibm_expt -= 4;
        top_digit = ibm_frac & IBM64_TOP;
    }
    leading_zeros = (int)((BITCOUNT_MAGIC >> (top_digit >> 51)) & 3U);

    ibm_frac <<= leading_zeros;
    ieee_expt = ibm_expt - 131 - leading_zeros;

    if (ieee_expt >= 0 && ieee_expt < IEEE32_MAXEXP) {
        /* normal case; shift right 32, with round-ties-to-even */
        npy_uint32 round_up = (ibm_frac & TIES_TO_EVEN_RSHIFT32) > 0U;
        ieee_frac = ((npy_uint32)(ibm_frac >> 31) + round_up) >> 1;
        return ieee_sign + ((npy_uint32)ieee_expt << 23) + ieee_frac;
    }
    else if (ieee_expt >= IEEE32_MAXEXP) {
        /* overflow */
        return ieee_sign + IEEE32_INFINITY;
    }
    else if (ieee_expt >= -32) {
        /* possible subnormal; shift right with round-ties-to-even */
        npy_uint64 mask = ~(TIES_TO_EVEN_MASK64 << (31 - ieee_expt));
        npy_uint32 round_up = (ibm_frac & mask) > 0U;
        ieee_frac = (
            (npy_uint32)(ibm_frac >> (31 - ieee_expt)) + round_up) >> 1;
        return ieee_sign + ieee_frac;
    }
    else {
        /* underflow to zero */
        return ieee_sign;
    }
}


/* IBM single-precision bit pattern to IEEE double-precision bit pattern. */

static npy_uint64
ibm32ieee64(npy_uint32 ibm)
{
    /* This is the simplest of the four cases: there's no need to check for
       overflow or underflow, no possibility of subnormal output, and never
       any rounding. */
    int ibm_expt, ieee_expt, leading_zeros;
    npy_uint32 ibm_frac, top_digit;
    npy_uint64 ieee_sign, ieee_frac;

    ieee_sign = (npy_uint64)(ibm & IBM32_SIGN) << 32;
    ibm_frac = ibm & IBM32_FRAC;

    /* Quick return for zeros. */
    if (!ibm_frac) {
        return ieee_sign;
    }

    /* Reduce shift by 2 to get a binary exponent from the hex exponent. */
    ibm_expt = (int)((ibm & IBM32_EXPT) >> 22);

    /* Normalise significand, then count leading zeros in top hex digit. */
    top_digit = ibm_frac & IBM32_TOP;
    while (top_digit == 0) {
        ibm_frac <<= 4;
        ibm_expt -= 4;
        top_digit = ibm_frac & IBM32_TOP;
    }
    leading_zeros = (int)((BITCOUNT_MAGIC >> (top_digit >> 19)) & 3U);

    /* Adjust exponents for the differing biases of the formats: the IBM bias
       is 64 hex digits, or 256 bits. The IEEE bias is 1023. The difference is
       767; we get an extra -1 from the different significand representations
       (0.f for IBM versus 1.f for IEEE), and another -1 to compensate for an
       evil trick that saves an operation: we don't remove the hidden 1-bit
       from the IEEE significand, so in the final addition that extra bit ends
       in incrementing the exponent by one. */
    ieee_expt = ibm_expt + 765 - leading_zeros;
    ieee_frac = (npy_uint64)ibm_frac << (29 + leading_zeros);
    return ieee_sign + ((npy_uint64)ieee_expt << 52) + ieee_frac;
}


/* IBM double-precision bit pattern to IEEE double-precision bit pattern. */

static npy_uint64
ibm64ieee64(npy_uint64 ibm)
{
    /* No overflow or underflow possible, but the precision of the
       IBM double-precision format exceeds that of its IEEE counterpart,
       so we'll frequently need to round. */
    int ibm_expt, ieee_expt, leading_zeros;
    npy_uint64 ibm_frac, top_digit;
    npy_uint64 ieee_sign, ieee_frac, round_up;

    ieee_sign = ibm & IBM64_SIGN;
    ibm_frac = ibm & IBM64_FRAC;

    /* Quick return for zeros. */
    if (!ibm_frac) {
        return ieee_sign;
    }

    /* Reduce shift by 2 to get a binary exponent from the hex exponent. */
    ibm_expt = (int)((ibm & IBM64_EXPT) >> 54);

    /* Normalise significand, then count leading zeros in top hex digit. */
    top_digit = ibm_frac & IBM64_TOP;
    while (top_digit == 0) {
        ibm_frac <<= 4;
        ibm_expt -= 4;
        top_digit = ibm_frac & IBM64_TOP;
    }
    leading_zeros = (int)((BITCOUNT_MAGIC >> (top_digit >> 51)) & 3U);

    ibm_frac <<= leading_zeros;
    ieee_expt = ibm_expt + 765 - leading_zeros;

    /* Right-shift by 3 bits (the difference between the IBM and IEEE
       significand lengths), rounding with round-ties-to-even. */
    round_up = (ibm_frac & TIES_TO_EVEN_RSHIFT3) > 0U;
    ieee_frac = ((ibm_frac >> 2) + round_up) >> 1;
    return ieee_sign + ((npy_uint64)ieee_expt << 52) + ieee_frac;
}
