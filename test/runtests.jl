using Revise
using MiniPL
using Test

# @testset "MiniPL.jl" begin

#     MiniPL.parse("Hello world!") isa Token
# end

const m = MiniPL
const progAssignLiteral = "var x:int := 42;"
const progAssignParens = "var x:int := (7*6); print x;"

@testset "Basic scanning" begin
 tokens = m.scanInput("Hello world")
 @test length(tokens) == 3
 @test tokens[1] isa Token
 @test tokens[2] isa Token
 @test tokens[3].class == m.eoi
end

@testset "Basic parsing" begin
 progTokens = m.scanInput(progAssignParens)
 progStatements = m.parseInput(progTokens)
 @test length(progStatements.statements) == 2
end
