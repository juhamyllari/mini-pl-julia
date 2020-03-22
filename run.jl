include("./src/MiniPL.jl")
using .MiniPL
const m = MiniPL

if length(ARGS) != 1
  println("USAGE: julia run.jl sourcefile")
  exit(1)
end

filename = ARGS[1]

if !isfile(filename)
  println("File $(filename) not found.")
  exit(1)
end

source = open(ARGS[1]) do file
  read(file, String)
end

source = try
  ascii(source)
catch e
  println("The source code contains non-ascii characters.")
  exit(1)
end

try
  m.run(source)
catch e
  showerror(stdout, e)
end

println()
exit(0)
