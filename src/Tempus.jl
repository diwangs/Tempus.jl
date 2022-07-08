module Tempus

include("ConfigParser.jl")
include("Paths.jl")
include("ProbTraversal.jl")

# don't use 'using' or 'import' so that all globals are compartmentalized?

function main()
    delay_graph, fwdtable, intent = ConfigParser.parseconf("artifacts/ecmp23.json")
    reducible_paths = Paths.get_reducible_paths_yen(delay_graph, Symbol(intent["src"] * "_in"), Symbol(intent["dst"] * "_out"), 10)
    ProbTraversal.traversestatic(delay_graph, reducible_paths, intent)
end

if !isinteractive()
    main()
end

end # module
