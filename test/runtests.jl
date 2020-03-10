using Revise
using MiniPL
using Test

# @testset "MiniPL.jl" begin

#     MiniPL.parse("Hello world!") isa Token
# end

const m = MiniPL
const progAssignLiteral = "var x:int := 42;"
const progAssignParens = "var x:int := (7*6); print x;"

const p1 = """
var X : int := 4 + (6 * 2);
print X;
"""

const p2 = """
var nTimes : int := 0;
print "How many times?";
read nTimes;
var x : int;
for x in 0..nTimes-1 do
  print x;
  print " : Hello, world!\n";
end for;
assert (x = (nTimes - 1));
"""

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
