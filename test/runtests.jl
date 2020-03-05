using Revise
using MiniPL
using Test

# @testset "MiniPL.jl" begin

#     MiniPL.parse("Hello world!") isa Token
# end

const m = MiniPL

@testset "Basic scanning" begin
 tokens = m.scanInput("Hello world")
 @test length(tokens) == 3
 @test tokens[1] isa Token
 @test tokens[2] isa Token
 @test tokens[3].type == m.eoi
end
