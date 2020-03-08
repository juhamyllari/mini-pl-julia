@enum TokenClass begin
  ident
  times
  plus
  minus
  divide
  log_not
  log_and
  equals
  less_than
  open_paren
  close_paren
  rng
  semicolon
  colon
  doublequote
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
symbol_initials = ['*', '+', '-', '/', '(', ')', '.', ';', ':', '!', '=', '<', '&'] 
digits = '0':'9'
unary_ops = Dict(
  log_not => '!'
)
binary_ops = Dict(
  times => '*',
  plus => '+',
  minus => '-',
  divide => '/',
  equals => '=',
  less_than => '<',
  log_and => '&'
  )
syntactic_symbols = Dict(
  open_paren => '(',
  close_paren => ')',
  colon => ':',
  semicolon => ';',
  doublequote => '"'
)
symbol_to_character = union(unary_ops, binary_ops, syntactic_symbols)
character_to_symbol = Dict([(sym => op) for (op, sym) ∈ symbol_to_character])

mutable struct Token
  class::TokenClass
  content::String
  line::Int
end

Token(class::TokenClass, content::String) = Token(class, content, 0)

function scanInput(input::AbstractString, next = 1)
  input *= end_of_input_symbol
  tokens = Array{Token,1}()
  lineNumber = 1
  while next < length(input)
    while input[next] in whitespace
      if input[next] == '\n'
        lineNumber += 1
      end
      next += 1
    end
    token, next = getToken(input, next)
    token.line = lineNumber
    push!(tokens, token)
  end
  push!(tokens, Token(eoi, string(end_of_input_symbol)))
  return tokens
end

function getToken(input, next)
  if input[next] ∈ ident_or_kw_initial
    return getIdentOrKw(input, next)
  end
  if input[next] ∈ symbol_initials
    return getOperator(input, next)
  end
  if input[next] ∈ digits
    return getInteger(input, next)
  end
  if input[next] == '"'
    return getString(input, next)
  end
end

function getIdentOrKw(input, next)
  initial = next
  while input[next] ∉ union(delimiters, symbol_initials) next += 1 end
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
  tokenClass = character_to_symbol[input[next]]
  return Token(tokenClass, string(input[next])), next+1
end

function getInteger(input, next)
  initial = next
  while input[next] ∈ digits next += 1 end
  return Token(int_literal, input[initial:next-1]), next
end

function getString(input, next)
  println("This is getString, next is ", next)
  initial = next
  next += 1
  while input[next] != '"'
    next += 1
    next >= length(input) && error("Reached the end of the program while
      scanning a string literal. Did you forget the closing quote?")
  end
  return Token(string_literal, input[initial+1:next-1]), next+1
end
