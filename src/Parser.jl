include("Scanner.jl")

abstract type Node end
abstract type Statement <: Node end
abstract type Value <: Node end

struct Statements <: Node
  statements::Array{Statement,1}
end

struct ValueType <: Node
  tok::Token
end

struct Declaration <: Statement
  variable::Token
  type::Token
  line::Int
end

struct DecAssignment <: Statement
  variable::Token
  type::Token
  value::Value
end

struct Assignment <: Statement
  variable::Token
  value::Value
  line::Int
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
  line::Int
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
  nxtclass() = input[next].class

  function match_term(terminal::TokenClass)
    println("match_term called with terminal $(terminal), next is $(nxtclass())")
    class = nxtclass()
    does_match = terminal == class
    if !does_match
      if terminal == semicolon && class == eoi
        error("Unexpected end of input. Did you forget a semicolon?")
      end
    end
    next += 1
    return does_match
  end
  
  function statements()
    println("this is program, nxtype is ", nxtclass())
    statements = Array{Node,1}()
    while nxtclass() ∉ [eoi, kw_end]
      push!(statements, statement())
      match_term(semicolon)
    end
    return Statements(statements)
  end

  function statement()
    println("this is statement, nxtype is ", nxtclass())
    t = nxtclass()
    if t == kw_var
      line = nxtok().line
      match_term(kw_var)
      var_id_tok = var_ident().tok
      match_term(colon)
      var_type_tok = type_keyword().tok
      if nxtclass() == assign
        match_term(assign)
        return DecAssignment(var_id_tok, var_type_tok, expr())
      end
      return Declaration(var_id_tok, var_type_tok, line)
    end
    if t == ident
      variable = var_ident().tok
      line = nxtok().line
      match_term(assign)
      value = expr()
      return Assignment(variable, value, line)
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
    if t == kw_assert
      line = nxtok().line
      match_term(kw_assert)
      match_term(open_paren)
      argument = expr()
      match_term(open_paren)
      return Assert(argument, line)
    end
    error("Failed to parse statement on line $(nxtok().line)")
  end

  function asg_tail()
    println("this is asg_tail, nxtype is ", nxtclass())
    if nxtclass() == assign
      match_term(assign)
      return expr()
    end
    return EmptyAssignmentTail()
  end

  function expr()
    println("this is expr, nxtype is ", nxtclass())
    if nxtclass() ∈ keys(unary_ops)
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
    println("this is unary_op, nxtype is ", nxtclass())
    t = nxtclass()
    tok = nxtok()
    match_term(t)
    return Operator(tok)
  end

  function operand()
    println("this is operand, nxtype is ", nxtclass())
    t = nxtclass()
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
    if t ∈ [int_literal, string_literal]
      match_term(t)
      return Literal(tok)
    end
  end

  function operation_tail()
    println("this is operation_tail, nxtype is ", nxtclass())
    t = nxtclass()
    if t ∈ keys(binary_ops)
      return OperationTail(operator(), operand())
    end
    return EmptyOperationTail()
  end

  function operator()
    println("this is operator, nxtype is ", nxtclass())
    t = nxtclass()
    tok = nxtok()
    if t ∈ keys(binary_ops)
      match_term(t)
      return Operator(tok)
    end
    error("Expected a binary operator, got ", tok)
  end

  function var_ident()
    println("this is var_ident, nxtype is ", nxtclass())
    tok = nxtok()
    match_term(ident)
    return VarIdent(tok)
  end

  function type_keyword()
    println("this is type_keyword, nxtype is ", nxtclass())
    t = nxtclass()
    if t ∈ [kw_bool, kw_int, kw_string]
      tok = nxtok()
      match_term(t)
      return ValueType(tok)
    end
    error("Expected a type, got ", nxtclass())
  end

  next = 1
  statements()
end

parseInput(source::String) = parseInput(scanInput(source))
