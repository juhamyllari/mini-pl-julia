module MiniPL

import Base: *,+,-,÷,<,!,&,==,showerror

include("Interpreter.jl")

export Token, scanInput, TokenClass

DEBUG = true

end # module
