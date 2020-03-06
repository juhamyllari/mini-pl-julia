module MiniPL

export Token, scanInput, TokenClass

@enum TokenClass begin
  ident
  times
  plus
  minus
  log_not
  equals
  less_than
  open_paren
  close_paren
  rng
  semicolon
  colon
  int_literal
  string_literal
  assign
  kw_var
  kw_for
  kw_end
  kw_in
  kw_do
  kw_read
  kw_print
  kw_int
  kw_string
  kw_bool
  kw_assert
  eoi
end

whitespace = [' ', '\t', '\n']
end_of_input_symbol = '$'
delimiters = union(whitespace, end_of_input_symbol)
ident_or_kw_initial = union('a':'z', 'A':'Z')
ident_or_kw_body = union(ident_or_kw_initial, '0':'9', '_')
keywords = Dict([
  "var" => kw_var, 
  "for" => kw_for,
  "end" => kw_end,
  "in" => kw_in,
  "do" => kw_do,
  "read" => kw_read,
  "print" => kw_print,
  "int" => kw_int,
  "string" => kw_string,
  "bool" => kw_bool,
  "assert" => kw_assert])
operator_initials = ['*', '+', '-', '(', ')', '.', ';', ':', '!', '=', '<'] 
digits = '0':'9'
unary_ops = Dict(
  log_not => '!'
)
binary_ops = Dict(
  times => '*',
  plus => '+',
  minus => '-',
  equals => '=',
  less_than => '<'
  )
syntactic_symbols = Dict(
  open_paren => '(',
  close_paren => ')',
  colon => ':',
  semicolon => ';'
)
operator_to_symbol = union(unary_ops, binary_ops, syntactic_symbols)
symbol_to_operator = Dict([(sym => op) for (op, sym) ∈ operator_to_symbol])

struct Token
  type::TokenClass
  content::String
end

function scanInput(input::AbstractString, next = 1)
  input *= end_of_input_symbol
  tokens = Array{Token,1}()
  while next < length(input)
    while input[next] in whitespace next += 1 end
    token, next = getToken(input, next)
    push!(tokens, token)
  end
  push!(tokens, Token(eoi, string(end_of_input_symbol)))
  return tokens
end

function getToken(input, next)
  if input[next] ∈ ident_or_kw_initial
    return getIdentOrKw(input, next)
  end
  if input[next] ∈ operator_initials
    return getOperator(input, next)
  end
  if input[next] ∈ digits
    return getInteger(input, next)
  end
end

function getIdentOrKw(input, next)
  initial = next
  while input[next] ∉ union(delimiters, operator_initials) next += 1 end
  str = input[initial:next-1]
  token = str ∈ keys(keywords) ? Token(keywords[str], str) : Token(ident, str)
  return token, next
end

function getOperator(input, next)
  if input[next] == '.'
    input[next+1] != '.' && error("expected two dots")
    return Token(rng, ".."), next+2
  end
  if input[next] == ':'
    input[next+1] == '=' && return Token(assign, ":="), next+2
    return Token(colon, ":"), next+1
  end
  tokenClass = symbol_to_operator[input[next]]
  return Token(tokenClass, string(input[next])), next+1
end

function getInteger(input, next)
  initial = next
  while input[next] ∈ digits next += 1 end
  return Token(int_literal, input[initial:next-1]), next
end

function parseInput(input::Array{Token,1})
  
  nxtype() = input[next].type

  function match_term(terminal::TokenClass)
    println("match_term called with terminal $(terminal), next is $(nxtype())")
    does_match = terminal == nxtype()
    next += 1
    return does_match
  end
  
  function program()
    println("this is program, nxtype is ", nxtype())
    return statement() && match_term(semicolon) && statements() && match_term(eoi)
  end

  function statements()
    println("this is statements, nxtype is ", nxtype())
    nxtype() ∈ [eoi, kw_end] && return true
    return statement() && match_term(semicolon) && statements()
  end

  function statement()
    println("this is statement, nxtype is ", nxtype())
    t = nxtype()
    t == kw_var && return match_term(kw_var) &&
                          var_ident() &&
                          match_term(colon) &&
                          tp() &&
                          asg_tail()
    t == ident && return var_ident() &&
                         match_term(assign) &&
                         expr()
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
    t == kw_read && return match_term(kw_read) &&
                           var_ident()
    t == kw_print && return match_term(kw_print) &&
                            expr()
    t == kw_assert && return match_term(kw_assert) &&
                             match_term(open_paren) &&
                             expr() &&
                             match_term(open_paren)
  end

  function asg_tail()
    println("this is asg_tail, nxtype is ", nxtype())
    nxtype() == assign && return match_term(assign) && expr()
  end

  function expr()
    println("this is expr, nxtype is ", nxtype())
    nxtype() ∈ keys(unary_ops) && return unary_op() && operand()
    return operand() && op_tail()
  end

  function unary_op()
    println("this is unary_op, nxtype is ", nxtype())
    return match_term(log_not)
  end

  function operand()
    println("this is operand, nxtype is ", nxtype())
    t = nxtype()
    if t == open_paren
      return match_term(open_paren) && expr() && match_term(close_paren)
    end
    return match_term(nxtype())
  end

  function op_tail()
    println("this is op_tail, nxtype is ", nxtype())
    t = nxtype()
    t ∈ keys(binary_ops) && return op() && operand()
    return true
  end

  function op()
    println("this is op, nxtype is ", nxtype())
    t = nxtype()
    t ∈ keys(binary_ops) && return match_term(t)
    error("Expected a binary operator, got ", nxtype())
  end

  function var_ident()
    println("this is var_ident, nxtype is ", nxtype())
    return match_term(ident)
  end

  function tp()
    println("this is tp, nxtype is ", nxtype())
    nxtype() ∈ [kw_bool, kw_int, kw_string] && return match_term(nxtype())
    error("Expected a type, got ", nxtype())
  end

  next = 1
  program()
end
  
end # module
