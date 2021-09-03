const IBM32_SIGN = (UInt32(0x80000000))
const IBM32_EXPT = (UInt32(0x7f000000))
const IBM32_FRAC = (UInt32(0x00ffffff))
const IBM32_TOP =  (UInt32(0x00f00000))
const TIES_TO_EVEN_MASK32 = (UInt32(0xfffffffd))

const IBM64_SIGN = (UInt64(0x8000000000000000))
const IBM64_EXPT = (UInt64(0x7f00000000000000))
const IBM64_FRAC = (UInt64(0x00ffffffffffffff))
const IBM64_TOP =  (UInt64(0x00f0000000000000))
const TIES_TO_EVEN_MASK64 = (UInt64(0xfffffffffffffffd))

# Masks used for 3-bit and 32-bit rounded right-shifts of a 64-bit quantity.
#   The masks comprise the parity bit and the trailing bits for the shift. 
const TIES_TO_EVEN_RSHIFT3 =  (UInt64(0x000000000000000b))
const TIES_TO_EVEN_RSHIFT32 = (UInt64(0x000000017fffffff))

const IEEE32_MAXEXP = 254     # Maximum biased exponent for finite values. 
const IEEE32_INFINITY = (UInt32(0x7f800000))

# Constant used to count number of leading bits in a nonzero hex digit
# via `(BITCOUNT_MAGIC >> (hex_digit*2)) & 3U`. */
const BITCOUNT_MAGIC = (UInt32(0x000055af))


"""
IBM single-precision bit pattern to IEEE single-precision bit pattern.
"""

function ibm32ieee32(ibm::UInt32)::UInt32
    # Overflow and underflow possible; rounding can only happen
    # in subnormal cases.
    # int ibm_expt, ieee_expt, leading_zeros;
    # npy_uint32 ibm_frac, top_digit;
    # npy_uint32 ieee_sign, ieee_frac;

    ieee_sign = ibm & IBM32_SIGN
    ibm_frac = ibm & IBM32_FRAC

    # Quick return for zeros. 
    if ibm_frac == 0
        return ieee_sign
    end

    # Reduce shift by 2 to get a binary exponent from the hex exponent.
    ibm_expt = Int((ibm & IBM32_EXPT) >> 22)

    # Normalise significand, then count leading zeros in top hex digit.
    top_digit = ibm_frac & IBM32_TOP
    while top_digit == 0
        ibm_frac <<= 4
        ibm_expt -= 4
        top_digit = ibm_frac & IBM32_TOP
    end
    leading_zeros = Int32((BITCOUNT_MAGIC >> (top_digit >> 19)) & 0x3)
    ibm_frac <<= leading_zeros

    # Adjust exponents for the differing biases of the formats: the IBM bias
    # is 64 hex digits, or 256 bits. The IEEE bias is 127. The difference is
    # -129; we get an extra -1 from the different significand representations
    # (0.f for IBM versus 1.f for IEEE), and another -1 to compensate for an
    # evil trick that saves an operation: on the fast path: we don't remove the
    # hidden 1-bit from the IEEE significand, so in the final addition that
    # extra bit ends in incrementing the exponent by one. */
    ieee_expt = ibm_expt - 131 - leading_zeros

    if ieee_expt >= 0 && ieee_expt < IEEE32_MAXEXP
        # normal case; no shift needed 
        ieee_frac = ibm_frac;
        return ieee_sign + (UInt32(ieee_expt) << 23) + ieee_frac;
    elseif ieee_expt >= IEEE32_MAXEXP
        # overflow 
        return ieee_sign + IEEE32_INFINITY;
    elseif ieee_expt >= -32
        # possible subnormal result; shift significand right by -ieee_expt
        # bits, rounding the result with round-ties-to-even.
        #
        # The round-ties-to-even code deserves some explanation: out of the
        # bits we're shifting out, let's call the most significant bit the
        # "rounding bit", and the rest the "trailing bits". We'll call the
        # least significant bit that *isn't* shifted out the "parity bit".
        # So for an example 5-bit shift right, we'd label the bits as follows:
        #
        # Before the shift:
        #
        #         ...xxxprtttt
        #                    ^
        #    msb            lsb
        #
        # After the shift:
        #
        #              ...xxxp
        #                    ^
        #    msb            lsb
        #
        # with the result possibly incremented by one.
        #
        # For round-ties-to-even, we need to round up if both (a) the rounding
        # bit is 1, and (b) either the parity bit is 1, or at least one of the
        # trailing bits is 1. We construct a mask that has 1-bits in the
        # parity bit position and trailing bit positions, and use that to
        # check condition (b). So for example in the 5-bit shift right, the
        # mask looks like this:
        #
        #         ...000101111 : mask
        #         ...xxxprtttt : ibm_frac
        #                    ^
        #    msb            lsb
        #
        # We then shift right by (shift - 1), add 1 if (ibm & mask) is
        # nonzero, and then do a final shift by one to get the rounded
        # value. Note that this approach avoids the possibility of
        # trying to shift a width-32 value by 32, which would give
        # undefined behaviour (see C99 6.5.7p3).
        #
        mask = ~(TIES_TO_EVEN_MASK32 << (-1 - ieee_expt))
        round_up = (ibm_frac & mask) > 0x0
        ieee_frac = ((ibm_frac >> (-1 - ieee_expt)) + round_up) >> 1
        return ieee_sign + ieee_frac
    else 
        # underflow to zero 
        return ieee_sign;
    end
end


"""
IBM double-precision bit pattern to IEEE single-precision bit pattern.
"""

function ibm64ieee32( ibm::UInt32)::UInt32
    # Overflow and underflow possible; rounding can occur in both
    # normal and subnormal cases. 
    # int ibm_expt, ieee_expt, leading_zeros;
    # npy_uint64 ibm_frac, top_digit;
    # npy_uint32 ieee_sign, ieee_frac;

    ieee_sign = (ibm & IBM64_SIGN) >> 32
    ibm_frac = ibm & IBM64_FRAC

    # Quick return for zeros. 
    if ibm_frac==0
        return ieee_sign
    end

    # Reduce shift by 2 to get a binary exponent from the hex exponent. 
    ibm_expt = Int((ibm & IBM64_EXPT) >> 54)

    # Normalise significand, then count leading zeros in top hex digit. 
    top_digit = ibm_frac & IBM64_TOP
    while top_digit == 0
        ibm_frac <<= 4
        ibm_expt -= 4
        top_digit = ibm_frac & IBM64_TOP
    end
    leading_zeros = Int((BITCOUNT_MAGIC >> (top_digit >> 51)) & 0x3)

    ibm_frac <<= leading_zeros;
    ieee_expt = ibm_expt - 131 - leading_zeros;

    if ieee_expt >= 0 && ieee_expt < IEEE32_MAXEXP
        # normal case; shift right 32, with round-ties-to-even 
        round_up = (ibm_frac & TIES_TO_EVEN_RSHIFT32) > 0x0
        ieee_frac = ((npy_uint32)(ibm_frac >> 31) + round_up) >> 1
        return ieee_sign + ((npy_uint32)ieee_expt << 23) + ieee_frac
    elseif ieee_expt >= IEEE32_MAXEXP
        # overflow 
        return ieee_sign + IEEE32_INFINITY
    elseif ieee_expt >= -32
        # possible subnormal; shift right with round-ties-to-even 
        mask = ~(TIES_TO_EVEN_MASK64 << (31 - ieee_expt))
        round_up = (ibm_frac & mask) > 0x0
        ieee_frac = UInt32((ibm_frac >> (31 - ieee_expt)) + round_up) >> 1
        return ieee_sign + ieee_frac
    else 
        # underflow to zero 
        return ieee_sign
    end
end


"""
IBM single-precision bit pattern to IEEE double-precision bit pattern.

This is the simplest of the four cases: there's no need to check for
overflow or underflow, no possibility of subnormal output, and never
any rounding. 

"""


function ibm32ieee64(ibm::UInt32)::UInt64
    ieee_sign = UInt64((ibm & IBM32_SIGN)) << 32
    ibm_frac = ibm & IBM32_FRAC

    # Quick return for zeros. 
    if ibm_frac == 0
        return ieee_sign
    end

    # Reduce shift by 2 to get a binary exponent from the hex exponent. 
    ibm_expt = Int((ibm & IBM32_EXPT) >> 22)

    # Normalise significand, then count leading zeros in top hex digit. 
    top_digit = ibm_frac & IBM32_TOP
    while top_digit == 0
        ibm_frac <<= 4
        ibm_expt -= 4
        top_digit = ibm_frac & IBM32_TOP
    end
    leading_zeros = Int32((BITCOUNT_MAGIC >> (top_digit >> 19)) & 0x3)
    ibm_frac <<= leading_zeros

    # Adjust exponents for the differing biases of the formats: the IBM bias
    # is 64 hex digits, or 256 bits. The IEEE bias is 1023. The difference is
    # 767; we get an extra -1 from the different significand representations
    # (0.f for IBM versus 1.f for IEEE), and another -1 to compensate for an
    # evil trick that saves an operation: we don't remove the hidden 1-bit
    # from the IEEE significand, so in the final addition that extra bit ends
    # in incrementing the exponent by one. */
    ieee_expt = ibm_expt + 765 - leading_zeros
    ieee_frac = UInt64(ibm_frac) << (29 + leading_zeros)
    return ieee_sign + (UInt64(ieee_expt) << 52) + ieee_frac
end


"""
IBM double-precision bit pattern to IEEE double-precision bit pattern.
"""


function ibm64ieee64(ibm::UInt64)::UInt64
    # No overflow or underflow possible, but the precision of the
    # IBM double-precision format exceeds that of its IEEE counterpart,
    # so we'll frequently need to round. */
    # int ibm_expt, ieee_expt, leading_zeros;
    # npy_uint64 ibm_frac, top_digit;
    # npy_uint64 ieee_sign, ieee_frac, round_up;

    ieee_sign = ibm & IBM64_SIGN
    ibm_frac = ibm & IBM64_FRAC

    # Quick return for zeros. 
    if ibm_frac == 0
        return ieee_sign;
    end

    # Reduce shift by 2 to get a binary exponent from the hex exponent. 
    ibm_expt = Int((ibm & IBM64_EXPT) >> 54);

    # Normalise significand, then count leading zeros in top hex digit. 
    top_digit = ibm_frac & IBM64_TOP
    while top_digit == 0
        ibm_frac <<= 4
        ibm_expt -= 4
        top_digit = ibm_frac & IBM64_TOP
    end
    leading_zeros = Int((BITCOUNT_MAGIC >> (top_digit >> 51)) & 0x3)

    ibm_frac <<= leading_zeros
    ieee_expt = ibm_expt + 765 - leading_zeros

    # Right-shift by 3 bits (the difference between the IBM and IEEE
    # significand lengths), rounding with round-ties-to-even. 
    round_up = (ibm_frac & TIES_TO_EVEN_RSHIFT3) > 0x0;
    ieee_frac = ((ibm_frac >> 2) + round_up) >> 1
    return ieee_sign + (UInt64(ieee_expt) << 52) + ieee_frac;
end
