using Test, CSV, ibm2ieee

# ibm32 requires two checks
check(ibm::UInt32, ieee::Float64) = t32(ibm, ieee) && t64(ibm, ieee)
t32(ibm::UInt32, ieee::Float64) = reinterpret(Float32, ibm2ieee.ibm32ieee32(ibm)) == Float32(ieee)

# we can't verify guarantee equality because ibm32=>ieee32 is lossy
# but we can validate against the lossage
t64(ibm::UInt32, ieee::Float64) = Float32(reinterpret(Float64, ibm2ieee.ibm32ieee64(ibm))) == Float32(ieee)

# ibm64 only requires one check. 
check(ibm::UInt64, ieee::Float64) = reinterpret(Float64, ibm2ieee.ibm64ieee64(ibm)) == ieee

# examples from wikipedia and other random sources verified by Python version
@test check(0xc276a000, -118.625)
@test check(0xC2808000, -128.5)
@test check(0x40600000, 0.375)
@test check(0xBEC80000, -0.0030517578)
@test check(0x42808000, 128.5)
@test check(0x427B7333, 123.45)

@test check(0x427B733333333333, 123.45)
@test check(0x4280000000000000, 128.0)
@test check(0x4060000000000000, 0.375)

# now check 10,000 randomly chosen bit patterns
@test begin
    ibm = CSV.File("input.csv", type=UInt32).ibm
    ieee32 = CSV.File("output.csv").ieee
    ieee64 = CSV.File("output64.csv").ieee
    u32 = reinterpret.(Float32, ibm2ieee.ibm32ieee32.(ibm))
    u64 = reinterpret.(Float64, ibm2ieee.ibm32ieee64.(ibm))
    return all(isinf.(ieee32[isinf.(u32)])) && all(u32[.!isinf.(u32)] .== ieee32[.!isinf.(u32)]) && all(u64 == ieee64)
end



