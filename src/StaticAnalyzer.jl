include("Parser.jl")

default_int_value = -1
default_bool_value = false
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
  if tc == kw_int return SValue(MInt) end
  if tc == kw_bool return SValue(MBool) end
  if tc == kw_string return SValue(MString) end
end

function SValue(type::MPLType)
  if type == MInt return SValue(type, default_int_value) end
  if type == MBool return SValue(type, default_bool_value) end
  if type == MString return SValue(type, default_string_value) end
end

(*)(left::SValue, right::SValue) = SValue(MInt, left.value * right.value)

function (+)(left::SValue, right::SValue)
  if left.type == MInt
    return SValue(MInt, left.value + right.value)
  elseif left.type == MString
    return SValue(MString, left.value * right.value)
  end
end

(-)(left::SValue, right::SValue) = SValue(MInt, left.value - right.value)
(÷)(left::SValue, right::SValue) = SValue(MInt, left.value ÷ right.value)
(==)(left::SValue, right::SValue) = SValue(MBool, left.value == right.value)
(<)(left::SValue, right::SValue) = SValue(left.type, left.value < right.value)
(&)(left::SValue, right::SValue) = SValue(left.type, left.value & right.value)
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

unary_result_types = Dict(
  (MBool, !) => MBool
)

binary_result_types = Dict(
  (MBool, &) => MBool,
  (MInt, *) => MInt,
  (MInt, +) => MInt,
  (MInt, -) => MInt,
  (MInt, ÷) => MInt,
  (MInt, <) => MBool,
  (MBool, <) => MBool,
  (MString, <) => MBool,
  (MInt, ==) => MBool,
  (MBool, ==) => MBool,
  (MString, ==) => MBool,
  (MInt, ÷) => MInt,
  (MString, +) => MString,
)

mutable struct SymbolTable
  table::Dict{String,Tuple{SValue, Bool}}
end

SymbolTable() = SymbolTable(Dict{String,Tuple{SValue, Bool}}())

function addOrUpdateSymbol(st::SymbolTable, symbol::String, sv::SValue)
  if hasSymbol(st, symbol) && st.table[symbol][2]
    error("Attempting to update iteration variable $(symbol)")
  end
  push!(st.table, symbol => (sv, false))
end

function hasSymbol(st::SymbolTable, symbol::String)
  return symbol ∈ keys(st.table)
end

function getValue(st::SymbolTable, symbol::String)
  return st.table[symbol][1]
end

function setIterationVariable(st::SymbolTable, symbol::String, value::Int)
  push!(st.table, symbol => (SValue(MInt, value), true))
end

function  releaseIterationVariable(st::SymbolTable, symbol::String)
  value = st.table[symbol][1]
  push!(st.table, symbol => (value, false))
end

function staticAnalysis(program::Statements)
  st = SymbolTable()
  for stmt in program.statements
    staticAnalysis(stmt, st)
  end
end

function staticAnalysis(r::Read, st::SymbolTable)
  varName = r.variable.content
  if !hasSymbol(st, varName)
    error("Attempting to read into an unassigned variable on line $(r.line).")
  end
end

function staticAnalysis(a::Assert, st::SymbolTable)
  if typeCheck(a.argument, st) != MBool
    println("Asserting a non-boolean value on line $(a.line).")
  end
end

function staticAnalysis(d::Declaration, st::SymbolTable)
  varName = d.variable.content
  if hasSymbol(st, varName)
    error("Attempting to declare existing variable $(varName) on line $(d.line).")
  else
    addOrUpdateSymbol(st, varName, SValue(d.type.class))
  end
end

function staticAnalysis(d::DecAssignment, st::SymbolTable)
  varName = d.variable.content
  if hasSymbol(st, varName)
    error("Attempting to declare existing variable $(varName) on line $(d.line).")
  else
    addOrUpdateSymbol(st, varName, SValue(typeCheck(d.value, st)))
  end
end

function staticAnalysis(f::For, st::SymbolTable)
  varName = f.variable.content
  setIterationVariable(st, varName, 1)
  for stmt in f.body.statements
    staticAnalysis(stmt, st)
  end
  releaseIterationVariable(st, varName)
end

function staticAnalysis(p::Print, st::SymbolTable)
  typeCheck(p.argument, st)
end

function staticAnalysis(a::Assignment, st::SymbolTable)
  varName = a.variable.content
  if !hasSymbol(st, varName)
    error("Attempting to assign a value to an undeclared variable on line $(a.line).")
  end
  variableType = getValue(st, varName).type
  valueType = typeCheck(a.value, st)
  if variableType != valueType
    error("""Attempting to assign a value of type $(valueType)
             to a variable of type $(variableType) on line $(a.line).""")
  end
  addOrUpdateSymbol(st, varName, evaluate(a.value, st))
end

function typeCheck(l::Literal, st::SymbolTable)
  class = l.token.class
  class == int_literal && return MInt
  class ∈ [kw_true, kw_false] && return MBool
  class == string_literal && return MString
end

function typeCheck(u::UnaryOperation, st::SymbolTable)
  operandType = typeCheck(u.operand, st)
  operatorFunction = operator_to_function[u.operator.class]
  return unary_result_types[(operandType, operatorFunction)]
end

function typeCheck(b::BinaryOperation, st::SymbolTable)
  leftType = typeCheck(b.leftOperand, st)
  rightType = typeCheck(b.rightOperand, st)
  if leftType != rightType
    error("Operand type mismatch on line $(b.line)")
  end
  operatorFunction = operator_to_function[b.operator.class]
  if (leftType, operatorFunction) ∈ keys(binary_result_types)
    return binary_result_types[(leftType, operatorFunction)]
  else
    error("Operator \"$(b.operator.content)\" on line $(b.line) is not valid for provided argument types.")
  end
end

function typeCheck(v::Var, st::SymbolTable)
  return getValue(st, v.variable.content).type
end
