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
  open_paren => '(',
  close_paren => ')',
  semicolon => ';',
  colon => ':',
  equals => '=',
  less_than => '<'
)
operator_to_symbol = union(unary_ops, binary_ops)
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
  # println("getIdentOrKw called with next=$(next)")
  initial = next
  while input[next] ∉ union(delimiters, operator_initials) next += 1 end
  str = input[initial:next-1]
  # println("getIdentOrKw found string ", str)
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
    does_match = terminal.type == nxtype()
    next += 1
    return does_match
  end
  
  function program()
    return statement() && match_term(semicolon) && statements()
  end

  function statements()
    nxtype() == eoi && return
    return statement() && match_term(semicolon) && statements()
  end

  function statement()
    t = nxtype()
    t == kw_var && return var_ident() && match_term(colon) && tp() && asg_tail()
  end

  function asg_tail()
    nxtype() == assign && return match_term(assign) && expr()
  end

  function expr()
    nxtype() ∈ keys(unary_ops) && return unary_op() && operand()
    return operand() && op_tail()
  end

  function unary_op()
    return match_term(log_not)
  end

  function operand()
    if nxtype() == open_paren
      return match_term(open_paren) && expr() && match_term(close_paren)
    end
    return match_term(nxtype())
  end

  function op_tail()
    t = nxtype()
    t ∈ keys(binary_ops) && return op() && operand()
  end

  function op()
    
  end

  function var_ident()
      
  end

  function tp()
      
  end

  next = 1
end
  
end # module
