module Tempus

include("ConfigParser.jl")
include("Paths.jl")
include("ProbTraversal.jl")

# don't use 'using' or 'import' so that all globals are compartmentalized?

function main()
    topgraph, delaygraph, fwdtable, intent = ConfigParser.parseconf("artifacts/Highwinds.json")
    # println(ne(topgraph))
    # reduciblepaths = Paths.get_reducible_paths_yen(topgraph, Symbol(intent["src"]), Symbol(intent["dst"]), 1000)
    # reduciblepaths = Paths.get_reducible_paths_yen(delaygraph, Symbol(intent["src"] * "_in"), Symbol(intent["dst"] * "_out"), 500)
    # println(size(reduciblepaths))
    # ProbTraversal.traversestatic(delaygraph, reduciblepaths, intent)
    prob = ProbTraversal.traverse_topology_first(topgraph, intent)
    println(prob)
end

if !isinteractive()
    main()
end

end # module
