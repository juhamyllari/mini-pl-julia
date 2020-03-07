module MiniPL

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

function evaluate(node::Value, vars)
  if node isa Literal
    value = parse(Int, node.tok.content) 
    return SValue(MInt, value)
  end
  if node isa Var
    return vars[node.tok.content]
  end
  if node isa UnaryOperation
    return evalUnary(node)
  end
end

function evalUnary(node::UnaryOperation)
  if node.operator.type == log_not
    return SValue(MBool, !(evaluate(node.operand).value))
  end
end

function executeStatement(s::Statement)
  vars = Dict{String,SValue}()
  if s isa DecAssignment
    value = 
    push!(vars, s.variable => s.)
  end
end
  
end # module
