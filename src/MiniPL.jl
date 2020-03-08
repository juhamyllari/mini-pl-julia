module MiniPL

import Base: *,+,-,÷,<,!,&

export Token, scanInput, TokenClass

include("Parser.jl")

default_int_value = 0
default_bool_value = true
default_string_value = ""

@enum MPLType begin
  MInt
  MBool
  MString
end

struct SValue
  type::MPLType
  value::Union{Int,Bool,String}
end

function SValue(tc::TokenClass)
  if tc == kw_int return SValue(MInt, 0) end
  if tc == kw_bool return SValue(MBool, false) end
  if tc == kw_string return SValue(MString, "") end
end

(*)(left::SValue, right::SValue) = SValue(MInt, left.value * right.value)
(+)(left::SValue, right::SValue) = SValue(MInt, left.value + right.value)
(-)(left::SValue, right::SValue) = SValue(MInt, left.value - right.value)
(÷)(left::SValue, right::SValue) = SValue(MInt, left.value ÷ right.value)
(<)(left::SValue, right::SValue) = SValue(MBool, left.value < right.value)
(&)(left::SValue, right::SValue) = SValue(MBool, left.value & right.value)
(!)(operand::SValue) = SValue(MBool, !operand.value)

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

executeProgram(p::Statements) = executeStatements(p.statements)
run(program::String) = executeProgram(parseInput(scanInput(program)))

executeStatement(s::Statement) = executeStatement(s, vars = Dict{String,SValue}())

function executeStatement(d::Declaration, vars::Dict)
  varName = d.variable.content
  if varName ∈ keys(vars)
    error("Attempting to declare existing variable $(varName) on line $(d.line).")
  else
    push!(vars, varName => SValue(d.type.class))
  end
end

function executeStatement(d::DecAssignment, vars::Dict)
  push!(vars, d.variable.content => evaluate(d.value, vars))
end

function executeStatement(a::Assignment, vars::Dict)
  varName = a.variable.content
  if varName ∈ keys(vars)
    push!(vars, varName => evaluate(a.value, vars))
  else
    error("Attempting to assign to undeclared variable $(varName) on line $(a.line).")
  end
end

function executeStatement(p::Print, vars::Dict)
    println(evaluate(p.argument, vars).value)
end

function executeStatement(a::Assert, vars::Dict)
    if !(evaluate(a.argument, vars).value)
      println("Assertion on line $(a.line) failed.")
    end
end

end # module
