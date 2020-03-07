module MiniPL

import Base: *,+,-,÷,<,!

export Token, scanInput, TokenClass

include("Parser.jl")

@enum MPLType begin
  MInt
  MBool
  MString
end

struct SValue
  type::MPLType
  value::Union{Int,Bool,String}
end

*(left::SValue, right::SValue) = SValue(MInt, left.value * right.value)
+(left::SValue, right::SValue) = SValue(MInt, left.value + right.value)
-(left::SValue, right::SValue) = SValue(MInt, left.value - right.value)
÷(left::SValue, right::SValue) = SValue(MInt, left.value ÷ right.value)
<(left::SValue, right::SValue) = SValue(MBool, left.value < right.value)
!(operand::SValue) = SValue(MBool, !operand.value)

operator_to_function = Dict(
  times => *,
  plus => +,
  minus => -,
  divide => ÷,
  equals => ==,
  log_and => &,
  log_not => !,
  less_than => <
)

function evaluate(l::Literal)
  if l.tok.class == int_literal
    value = parse(Int, l.tok.content)
    return SValue(MInt, value)
  end
  if l.tok.class == string_literal
    return SValue(MString, l.tok.content)
  end
end

evaluate(l::Literal, vars) = evaluate(l)

function evaluate(v::Var, vars)
  return vars[v.variable.content]
end
    
function evaluate(node::UnaryOperation, vars)
  operation = operator_to_function[node.operator.class]
  return operation(evaluate(node.operand, vars))
end

function evaluate(node::BinaryOperation, vars)
  operation = operator_to_function[node.operator.class]
  left = evaluate(node.leftOperand, vars)
  right = evaluate(node.rightOperand, vars)
  return operation(left, right)
end

function executeStatements(statements::Array{Statement,1})
  vars = Dict{String,SValue}()
  for statement in statements
    executeStatement(statement, vars)
  end
end

executeProgram(p::Program) = executeStatements(p.statements)
run(program::String) = executeProgram(parseInput(scanInput(program)))

function executeStatement(s::Statement, vars::Dict)
  if s isa DecAssignment
    push!(vars, s.variable.content => evaluate(s.value, vars))
  end
  if s isa Print
    println(evaluate(s.argument, vars).value)
  end
end

executeStatement(s::Statement) = executeStatement(s, vars = Dict{String,SValue}())

end # module
