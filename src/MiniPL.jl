module MiniPL

export Token, scanInput

@enum TokenClass begin
  ident
  times
  plus
  minus
  open_paren
  close_paren
  rng
  semicolon
  colon
  int_literal
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
end

whitespace = [' ', '\t', '\n']
end_of_input_symbol = '$'
separators = union(whitespace, end_of_input_symbol)
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
operator_initials = ['*', '+', '-', '(', ')', '.', ';', ':'] 
digits = '0':'9'
operator_to_symbol = Dict(
  times => '*',
  plus => '+',
  minus => '-',
  open_paren => '(',
  close_paren => ')',
  semicolon => ';',
  colon => ':'
)
symbol_to_operator = Dict([(sym => op) for (op, sym) ∈ operator_to_symbol])

struct Token
  type::TokenClass
  content::String
end

function scanInput(input::AbstractString, next = 1)
  input *= end_of_input_symbol
  tokens = []
  while next < length(input)
    while input[next] in whitespace next += 1 end
    token, next = getToken(input, next)
    push!(tokens, token)
  end
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
  while input[next] ∉ union(separators, operator_initials) next += 1 end
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
  tokenClass = symbol_to_operator[input[next]]
  return Token(tokenClass, string(input[next])), next+1
end

function getInteger(input, next)
  initial = next
  while input[next] ∈ digits next += 1 end
  return Token(int_literal, input[initial:next-1]), next
end

end # module
