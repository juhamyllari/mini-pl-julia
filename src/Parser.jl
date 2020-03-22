include("Scanner.jl")

struct SyntaxException <: Exception
  msg::String
end

abstract type Node end
abstract type Statement <: Node end
abstract type Value <: Node end

struct Statements <: Node
  statements::Array{Statement,1}
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

struct LeftVal <: Node
  token::Token
  line::Int
end

"""
The main function of the parser. Maintains an index ("next") to point
at the token to be processed next. Builds the AST by calling mutually
recursive parsing functions, starting with statements().
"""
function parseInput(input::Array{Token,1})
  
  # Gets the next token.
  function nxtok()
    if next > length(input)
      throw(SyntaxException(
        "Failed to parse program. Do all your statements have a terminating semicolon?"))
    end
    return input[next]
  end

  nxtclass() = nxtok().class

  # Convenience function. Returns the token, its class and its line number.
  function tok_class_line()
    tok = nxtok()
    return tok, tok.class, tok.line
  end

  """
  Consumes the next token, checking that the token class matches.
  """
  function match_term(terminal::TokenClass)
    DEBUG && println("match_term called in $(currentUnit) with terminal $(terminal), next is $(nxtclass())")
    token, class, line = tok_class_line()
    does_match = terminal == class
    if !does_match
      if terminal == semicolon && class == eoi
        throw(SyntaxException(
          "Unexpected end of input. Did you forget a semicolon?"))
      elseif terminal == ident && class ∈ values(keywords)
        throw(SyntaxException(
          "Expected a variable identifier but got keyword \"$(token.lexeme)\" on line $(line)."))
      else
        throw(SyntaxException(
          "Failed to parse $(currentUnit) on or around line $(line)."))
      end
    end
    next += 1
    return does_match
  end
  
  function statements()
    currentUnit = "group of statements"
    token, class, line = tok_class_line()
    DEBUG && println("this is statements, nxtype is ", class)
    stmts = Array{Node,1}()
    while nxtclass() ∉ [eoi, kw_end]
      push!(stmts, statement())
      match_term(semicolon)
    end
    return Statements(stmts, line)
  end

  function statement()
    currentUnit = "statement"
    token, class, line = tok_class_line()
    DEBUG && println("this is statement, nxtype is ", class)
    if class == kw_var
      # Parse a declaration or a declaration-assignment
      match_term(kw_var)
      leftval_tok = leftval_ident().token
      match_term(colon)
      token, class, line = tok_class_line()
      if class ∉ [kw_bool, kw_int, kw_string]
        throw(SyntaxException(
          "Expected a type keyword on line $(line), got '$(token.lexeme)'."))
      end
      var_type_tok = token
      match_term(class)
      if nxtclass() == assign
        match_term(assign)
        return DecAssignment(leftval_tok, var_type_tok, expr(), line)
      end
      return Declaration(leftval_tok, var_type_tok, line)
    end
    if class == ident
      # Parse an assignment
      leftval_tok = leftval_ident().token
      line = nxtok().line
      match_term(assign)
      value = expr()
      return Assignment(leftval_tok, value, line)
    end
    if class == kw_for
      # Parse a for-loop statement
      match_term(kw_for)
      iter_var_token = leftval_ident().token
      match_term(kw_in)
      from = expr()
      match_term(rng)
      to = expr()
      match_term(kw_do)
      body = statements()
      match_term(kw_end)
      match_term(kw_for)
      return For(iter_var_token, from, to, body, line)
    end
    if class == kw_read
      # Parse a read statement
      match_term(kw_read)
      return Read(leftval_ident().token, line)
    end
    if class == kw_print
      # Parse a print statement
      match_term(kw_print)
      return Print(expr(), line)
    end
    if class == kw_assert
      # Parse an assert statement
      match_term(kw_assert)
      if nxtclass() != open_paren
        throw(SyntaxException(
          "The argument of an assert statement must be in parentheses (line $(line))."))
      end
      match_term(open_paren)
      argument = expr()
      match_term(close_paren)
      return Assert(argument, line)
    end
    throw(SyntaxException(
      "Failed to parse statement on line $(line)"))
  end

  function expr()
    currentUnit = "expression"
    token, class, line = tok_class_line()
    DEBUG && println("this is expr, nxtclass is ", nxtclass())
    if class ∈ keys(unary_ops)
      return UnaryOperation(unary_op().token, operand(), line)
    end
    leftOperand = operand()
    token, class, line = tok_class_line()
    if class ∈ keys(binary_ops)
      currentUnit = "binary operation"
      DEBUG && println("this is expr parsing binary op, nxtclass is ", class)
      operatorToken = operator().token
      rightOperand = operand()
      return BinaryOperation(leftOperand, operatorToken, rightOperand, line)
    end
    return leftOperand
  end

  function unary_op()
    currentUnit = "unary operation"
    token, class, line = tok_class_line()
    DEBUG && println("this is unary_op, nxtclass is ", class)
    match_term(class)
    return Operator(token, line)
  end

  function operand()
    currentUnit = "operand"
    token, class, line = tok_class_line()
    DEBUG && println("this is operand, nxtclass is ", class)
    if class == open_paren
      match_term(open_paren)
      expression = expr()
      match_term(close_paren)
      return expression
    end
    if class == ident
      match_term(class)
      return Var(token, line)
    end
    if class ∈ [int_literal, string_literal, kw_true, kw_false]
      match_term(class)
      return Literal(token, line)
    end
    throw(SyntaxException(
      "Expected an operand on line $(line), got '$(token.lexeme)'."
    ))
  end

  function operator()
    currentUnit = "operator"
    token, class, line = tok_class_line()
    DEBUG && println("this is operator, nxtclass is ", class)
    if class ∈ keys(binary_ops)
      match_term(class)
      return Operator(token, line)
    end
    throw(SyntaxException(
      "Expected a binary operator on line $(line), got '$(token.lexeme)'."
    ))
  end

  function leftval_ident()
    currentUnit = "identifier"
    token, class, line = tok_class_line()
    DEBUG && println("this is leftval_ident, nxtclass is ", class)
    match_term(ident)
    return LeftVal(token, line)
  end

  if length(input) < 2
    throw(SyntaxException(
      "The empty string is not a valid program."
    ))
  end
  next = 1
  currentUnit = "program"
  statements()
end

parseInput(source::String) = parseInput(scanInput(source))
