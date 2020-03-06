module MiniPL

export Token, scanInput, TokenClass

include("Scanner.jl")

@enum MPLType begin
  type_int
  type_bool
  type_string
end

struct Node
end

struct Program <: Node
  stmt::Statement
  stmts::StatementList
end

struct StatementList <: Node
  stmt::Statement
  stmts::StatementList
end

struct EmptyOperationTail <: Node
end

struct EmptyStatementList <: StatementList
end

struct Statement <: Node
end

struct LeftVal <: Node
  var_name::ident
end

struct ValueType <: Node
  type::MPLType
end

struct Declaration <: Statement
end

struct DecAssignment <: Statement
end

struct Assignment <: Statement
end

struct AssignmentTail <: Node
end

struct EmptyAssignmentTail <: AssignmentTail
end

struct For <: Statement
end

struct Value <: Node
end

struct Literal <: Value
end

struct Operator <: Node
  op::TokenClass
end

struct BinaryOperation <: Value
end

struct UnaryOperation <: Value
end

struct Var <: Value
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
    # return statement() && match_term(semicolon) && statements() && match_term(eoi)
    stmt = statement()
    match_term(semicolon)
    stmts = statements()
    match_term(eoi)
    return Program(stmt, stmts)
  end

  function statements()
    println("this is statements, nxtype is ", nxtype())
    if nxtype() ∈ [eoi, kw_end]
      return EmptyStatementList
    end
    stmt = statement()
    match_term(semicolon)
    stmts = statements()
    # return statement() && match_term(semicolon) && statements()
    return StatementList(stmt, stmts)
  end

  function statement()
    println("this is statement, nxtype is ", nxtype())
    t = nxtype()
    if t == kw_var
      match_term(kw_var)
      var_id = var_ident()
      match_term(colon)
      var_type = tp()
      tail = asg_tail()
      if tail isa EmptyAssignmentTail
        return Declaration(var_id, var_type)
      end
      return DecAssignment(var_id, var_type, tail)
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
    if nxtype() == assign
      match_term(assign)
      return expr()
    end
    return EmptyAssignmentTail()
  end

  function expr()
    println("this is expr, nxtype is ", nxtype())
    if nxtype() ∈ keys(unary_ops)
      return UnaryOperation(unary_op(), operand())
    end
    oprnd = operand()
    tail = op_tail()
    if tail isa EmptyOperationTail
      return oprnd
    end
    return BinaryOperation(oprnd, tail)
  end

  function unary_op()
    println("this is unary_op, nxtype is ", nxtype())
    t = nxtype()
    match_term(t)
    return Operator(t)
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
