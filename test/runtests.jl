using Test, CSV, ibm2ieee

t32(ibm::UInt32, ieee::Float64) = reinterpret(Float32, ibm2ieee.ibm32ieee32(ibm)) == Float32(ieee)
t64(ibm::UInt32, ieee::Float64) = reinterpret(Float64, ibm2ieee.ibm32ieee64(ibm)) == ieee

t_short(ibm::UInt32, ieee::Float64) = t32(ibm, ieee) && t64(ibm, ieee)
t_long(ibm::UInt64, ieee::Float64) = reinterpret(Float64, ibm2ieee.ibm64ieee64(ibm)) == ieee

@test t_short(0xc276a000, -118.625)
@test t_short(0xC2808000, -128.5)
@test t_short(0x40600000, 0.375)
@test t_short(0xBEC80000, -0.0030517578125)
@test t_short(0x42808000, 128.5)
@test t_short(0x427B7333, 123.44999694824219)

@test t_long(0x427B733333333333, 123.45)
@test t_long(0x4280000000000000, 128.0)
@test t_long(0x4060000000000000, 0.375)

@test begin
    ibm = CSV.File("input.csv", type=UInt32).ibm
    ieee = CSV.File("output.csv").ieee
    u = reinterpret.(Float32, ibm2ieee.ibm32ieee32.(ibm))
    return all(isinf.(ieee[isinf.(u)])) && all(u[.!isinf.(u)] .== ieee[.!isinf.(u)])
end



