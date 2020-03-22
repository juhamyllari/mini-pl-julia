include("Parser.jl")

struct StaticAnalysisException <: Exception
  msg::String
end

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

function addOrUpdateSymbol(st::SymbolTable, symbol::String, sv::SValue, line=0::Int)
  if hasSymbol(st, symbol) && st.table[symbol][2]
    throw(StaticAnalysisException(
      "Attempting to update iteration variable $(symbol) on line $(line)."))
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

function staticAnalysis(AST::Statements)
  st = SymbolTable()
  for stmt in AST.statements
    staticAnalysis(stmt, st)
  end
end

function staticAnalysis(r::Read, st::SymbolTable)
  varName = r.variable.lexeme
  if !hasSymbol(st, varName)
    throw(StaticAnalysisException(
      "Attempting to read into an unassigned variable on line $(r.line)."))
  end
end

function staticAnalysis(a::Assert, st::SymbolTable)
  if typeCheck(a.argument, st) != MBool
    println("Asserting a non-boolean value on line $(a.line).")
  end
end

function staticAnalysis(d::Declaration, st::SymbolTable)
  varName = d.variable.lexeme
  if hasSymbol(st, varName)
    throw(StaticAnalysisException(
      "Attempting to declare existing variable $(varName) on line $(d.line)."))
  else
    addOrUpdateSymbol(st, varName, SValue(d.type.class), d.line)
  end
end

function staticAnalysis(d::DecAssignment, st::SymbolTable)
  varName = d.variable.lexeme
  if hasSymbol(st, varName)
    throw(StaticAnalysisException(
      "Attempting to declare existing variable $(varName) on line $(d.line)."))
  else
    addOrUpdateSymbol(st, varName, SValue(typeCheck(d.value, st)), d.line)
  end
end

function staticAnalysis(f::For, st::SymbolTable)
  varName = f.variable.lexeme
  if (hasSymbol(st, varName) && getValue(st, varName).type != MInt)
    throw(StaticAnalysisException(
      "Iteration variable on line $(f.line) has non-integer type."
    ))
  end
  if (typeCheck(f.from, st) != MInt)
    throw(StaticAnalysisException(
      "Range start value on line $(f.line) has non-integer type."
    ))
  end
  if (typeCheck(f.to, st) != MInt)
    throw(StaticAnalysisException(
      "Range end value on line $(f.line) has non-integer type."
    ))
  end
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
  varName = a.variable.lexeme
  if !hasSymbol(st, varName)
    throw(StaticAnalysisException(
      "Attempting to assign a value to an undeclared variable on line $(a.line)."
    ))
  end
  variableType = getValue(st, varName).type
  valueType = typeCheck(a.value, st)
  if variableType != valueType
    throw(StaticAnalysisException(
      """Attempting to assign a value of type $(valueType)
      to a variable of type $(variableType) on line $(a.line)."""
    ))
  end
  addOrUpdateSymbol(st, varName, SValue(valueType), a.line)
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
    throw(StaticAnalysisException(
      "Operand type mismatch on line $(b.line)"
    ))
  end
  operatorFunction = operator_to_function[b.operator.class]
  if (leftType, operatorFunction) ∈ keys(binary_result_types)
    return binary_result_types[(leftType, operatorFunction)]
  else
    throw(StaticAnalysisException(
      "Operator '$(b.operator.lexeme)' on line $(b.line) is not valid for provided argument types."))
  end
end

function typeCheck(v::Var, st::SymbolTable)
  varName = v.variable.lexeme
  if !hasSymbol(st, varName)
    throw(StaticAnalysisException(
      "Variable '$(varName)' on line $(v.line) has not been declared."
    ))
  end
  return getValue(st, varName).type
end
