include("Scanner.jl")

abstract type Node end
abstract type Statement <: Node end
abstract type Value <: Node end

struct Statements <: Node
  statements::Array{Statement,1}
  line::Int
end

struct ValueType <: Node
  token::Token
  line::Int
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
  line::Int
end

struct Assignment <: Statement
  variable::Token
  value::Value
  line::Int
end

struct For <: Statement
  variable::Token
  from::Value
  to::Value
  body::Statements
  line::Int
end

struct Read <: Statement
  variable::Token
  line::Int
end

struct Print <: Statement
  argument::Value
  line::Int
end

struct Assert <: Statement
  argument::Value
  line::Int
end

struct Literal <: Value
  token::Token
  line::Int
end

struct Operator <: Node
  token::Token
  line::Int
end

struct BinaryOperation <: Value
  leftOperand::Value
  operator::Token
  rightOperand::Value
  line::Int
end

struct UnaryOperation <: Value
  operator::Token
  operand::Value
  line::Int
end

struct Var <: Value
  variable::Token
  line::Int
end

struct VarIdent <: Node
  token::Token
  line::Int
end

function parseInput(input::Array{Token,1})
  
  function nxtok()
    if next > length(input)
      error("Failed to parse program. Do all your statements have a terminating semicolon?")
    end
    return input[next]
  end

  nxtclass() = nxtok().class

  function match_term(terminal::TokenClass)
    DEBUG && println("match_term called in $(currentUnit) with terminal $(terminal), next is $(nxtclass())")
    class = nxtclass()
    does_match = terminal == class
    if !does_match
      line = nxtok().line
      if terminal == semicolon && class == eoi
        error("Unexpected end of input. Did you forget a semicolon?")
      elseif terminal == ident && class ∈ values(keywords)
        error("Expected a variable identifier but got keyword \"$(nxtok().content)\" on line $(line).")
      else
        error("Failed to parse $(currentUnit) on or around line $(line).")
      end
    end
    next += 1
    return does_match
  end
  
  function statements()
    currentUnit = "group of statements"
    DEBUG && println("this is statements, nxtype is ", nxtclass())
    line = nxtok().line
    stmts = Array{Node,1}()
    while nxtclass() ∉ [eoi, kw_end]
      push!(stmts, statement())
      match_term(semicolon)
    end
    return Statements(stmts, line)
  end

  function statement()
    currentUnit = "statement"
    DEBUG && println("this is statement, nxtype is ", nxtclass())
    class = nxtclass()
    if class == kw_var
      line = nxtok().line
      match_term(kw_var)
      var_id_tok = var_ident().token
      match_term(colon)
      var_type_tok = type_keyword().token
      if nxtclass() == assign
        match_term(assign)
        return DecAssignment(var_id_tok, var_type_tok, expr(), line)
      end
      return Declaration(var_id_tok, var_type_tok, line)
    end
    if class == ident
      variable = var_ident().token
      line = nxtok().line
      match_term(assign)
      value = expr()
      return Assignment(variable, value, line)
    end
    if class == kw_for
      line = nxtok().line
      match_term(kw_for)
      var_token = var_ident().token
      match_term(kw_in)
      from = expr()
      match_term(rng)
      to = expr()
      match_term(kw_do)
      body = statements()
      match_term(kw_end)
      match_term(kw_for)
      return For(var_token, from, to, body, line)
    end
    if class == kw_read
      line = nxtok().line
      match_term(kw_read)
      return Read(var_ident().token, line)
    end
    if class == kw_print
      line = nxtok().line
      match_term(kw_print)
      return Print(expr(), line)
    end
    if class == kw_assert
      line = nxtok().line
      match_term(kw_assert)
      if nxtclass() != open_paren
        error("The argument of an assert statement must be in parentheses (line $(line)).")
      end
      match_term(open_paren)
      argument = expr()
      match_term(close_paren)
      return Assert(argument, line)
    end
    error("Failed to parse statement on line $(nxtok().line)")
  end

  function expr()
    currentUnit = "expression"
    DEBUG && println("this is expr, nxtype is ", nxtclass())
    if nxtclass() ∈ keys(unary_ops)
      line = nxtok().line
      return UnaryOperation(unary_op().token, operand(), line)
    end
    leftOperand = operand()
    if nxtclass() ∈ keys(binary_ops)
      currentUnit = "binary operation"
      DEBUG && println("this is expr parsing binary op, nxtype is ", nxtclass())
      class = nxtclass()
      line = nxtok().line
      operatorToken = operator().token
      rightOperand = operand()
      return BinaryOperation(leftOperand, operatorToken, rightOperand, line)
    end
    return leftOperand
  end

  function unary_op()
    currentUnit = "unary operation"
    DEBUG && println("this is unary_op, nxtype is ", nxtclass())
    class = nxtclass()
    token = nxtok()
    match_term(class)
    return Operator(token, token.line)
  end

  function operand()
    currentUnit = "operand"
    class = nxtclass()
    DEBUG && println("this is operand, nxtype is ", class)
    token = nxtok()
    if class == open_paren
      match_term(open_paren)
      expression = expr()
      match_term(close_paren)
      return expression
    end
    if class == ident
      match_term(class)
      return Var(token, token.line)
    end
    if class ∈ [int_literal, string_literal, kw_true, kw_false]
      match_term(class)
      return Literal(token, token.line)
    end
  end

  function operator()
    currentUnit = "operator"
    DEBUG && println("this is operator, nxtype is ", nxtclass())
    t = nxtclass()
    token = nxtok()
    if t ∈ keys(binary_ops)
      match_term(t)
      return Operator(token, token.line)
    end
    error("Expected a binary operator, got ", token)
  end

  function var_ident()
    currentUnit = "identifier"
    DEBUG && println("this is var_ident, nxtype is ", nxtclass())
    token = nxtok()
    match_term(ident)
    return VarIdent(token, token.line)
  end

  function type_keyword()
    currentUnit = "keyword"
    DEBUG && println("this is type_keyword, nxtype is ", nxtclass())
    class = nxtclass()
    if class ∈ [kw_bool, kw_int, kw_string]
      token = nxtok()
      match_term(class)
      return ValueType(token, token.line)
    end
    error("Expected a type, got ", nxtclass())
  end

  next = 1
  currentUnit = "program"
  statements()
end

parseInput(source::String) = parseInput(scanInput(source))
