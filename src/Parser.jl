include("Scanner.jl")

abstract type Node end
abstract type Statement <: Node end
abstract type Value <: Node end

struct Program <: Node
  statements::Array{Statement,1}
end

struct ValueType <: Node
  tok::Token
end

struct Declaration <: Statement
  variable::Token
  type::Token
end

struct DecAssignment <: Statement
  variable::Token
  type::Token
  value::Value
end

struct Assignment <: Statement
  variable::Token
  value::Value
end

struct AssignmentTail <: Node
end

struct EmptyAssignmentTail <: Node
end

struct For <: Statement
end

struct Read <: Statement
  variable::Token
end

struct Print <: Statement
  argument::Value
end

struct Assert <: Statement
  argument::Value
end

struct Literal <: Value
  tok::Token
end

struct Operator <: Node
  tok::Token
end

struct BinaryOperation <: Value
  leftOperand::Value
  operator::Token
  rightOperand::Value
end

struct OperationTail <: Node
  operator::Operator
  operand::Value
end

struct EmptyOperationTail <: Node
end

struct UnaryOperation <: Value
  operator::Token
  operand::Value
end

struct Var <: Value
  variable::Token
end

struct VarIdent <: Node
  tok::Token
end


function parseInput(input::Array{Token,1})
  
  nxtok() = input[next]
  nxtype() = input[next].type

  function match_term(terminal::TokenClass)
    println("match_term called with terminal $(terminal), next is $(nxtype())")
    does_match = terminal == nxtype()
    next += 1
    return does_match
  end
  
  function program()
    println("this is program, nxtype is ", nxtype())
    statements = Array{Node,1}()
    while nxtype() != eoi
      push!(statements, statement())
      match_term(semicolon)
    end
    return Program(statements)
  end

  function statement()
    println("this is statement, nxtype is ", nxtype())
    t = nxtype()
    if t == kw_var
      match_term(kw_var)
      var_id_tok = var_ident().tok
      match_term(colon)
      var_type_tok = type_keyword().tok
      tail = asg_tail()
      if tail isa EmptyAssignmentTail
        return Declaration(var_id_tok, var_type_tok)
      end
      return DecAssignment(var_id_tok, var_type_tok, tail)
    end
    if t == ident
      variable = var_ident().tok
      match_term(assign)
      value = expr()
      return Assignment(variable, value)
    end
    t == kw_for && return match_term(kw_for) &&
                          var_ident() &&
                          match_term(kw_in) &&
                          expr() &&
                          match_term(rng) &&
                          expr() &&
                          match_term(kw_do) &&
                          statements() &&
                          match_term(kw_end) &&
                          match_term(kw_for)
    if t == kw_read
      match_term(kw_read)
      return Read(var_ident().tok)
    end
    if t == kw_print
      match_term(kw_print)
      return Print(expr())
    end
    t == kw_assert && return match_term(kw_assert) &&
                             match_term(open_paren) &&
                             expr() &&
                             match_term(open_paren)
  end

  function asg_tail()
    println("this is asg_tail, nxtype is ", nxtype())
    if nxtype() == assign
      match_term(assign)
      return expr()
    end
    return EmptyAssignmentTail()
  end

  function expr()
    println("this is expr, nxtype is ", nxtype())
    if nxtype() ∈ keys(unary_ops)
      return UnaryOperation(unary_op().tok, operand())
    end
    oprnd = operand()
    tail = operation_tail()
    if tail isa EmptyOperationTail
      return oprnd
    end
    return BinaryOperation(oprnd, tail.operator.tok, tail.operand)
  end

  function unary_op()
    println("this is unary_op, nxtype is ", nxtype())
    t = nxtype()
    tok = nxtok()
    match_term(t)
    return Operator(tok)
  end

  function operand()
    println("this is operand, nxtype is ", nxtype())
    t = nxtype()
    tok = nxtok()
    if t == open_paren
      match_term(open_paren)
      expression = expr()
      match_term(close_paren)
      return expression
    end
    if t == ident
      match_term(t)
      return Var(tok)
    end
    match_term(t)
    return Literal(tok)
  end

  function operation_tail()
    println("this is operation_tail, nxtype is ", nxtype())
    t = nxtype()
    if t ∈ keys(binary_ops)
      return OperationTail(operator(), operand())
    end
    return EmptyOperationTail()
  end

  function operator()
    println("this is operator, nxtype is ", nxtype())
    t = nxtype()
    tok = nxtok()
    if t ∈ keys(binary_ops)
      match_term(t)
      return Operator(tok)
    end
    error("Expected a binary operator, got ", tok)
  end

  function var_ident()
    println("this is var_ident, nxtype is ", nxtype())
    tok = nxtok()
    match_term(ident)
    return VarIdent(tok)
  end

  function type_keyword()
    println("this is type_keyword, nxtype is ", nxtype())
    t = nxtype()
    if t ∈ [kw_bool, kw_int, kw_string]
      tok = nxtok()
      match_term(t)
      return ValueType(tok)
    end
    error("Expected a type, got ", nxtype())
  end

  next = 1
  program()
end
