module Tempus

include("ConfigParser.jl")
# include("Paths.jl")
# include("ProbTraversal.jl")
# using MetaGraphsNext
# using Graphs
include("ModifiedYen.jl")

# don't use 'using' or 'import' so that all globals are compartmentalized?

function main()
    topgraph, delaygraph, fwdtable, intent = ConfigParser.parseconf("artifacts/Highwinds.json")
    a = ModifiedYen.tempus_yen_stateful(topgraph, Symbol(intent["src"]), Symbol(intent["dst"]))
    println(a)
    # dj = dijkstra_shortest_paths(topgraph, code_for(topgraph, Symbol(intent["src"])), weights(topgraph), allpaths=true)
    # paths = enumerate_paths(dj, [code_for(topgraph, Symbol(intent["dst"])), code_for(topgraph, Symbol(intent["dst"]))])
    # println(paths)
    # prob = Paths.modified_yen(topgraph.graph, code_for(topgraph, Symbol(intent["src"])), code_for(topgraph, Symbol(intent["dst"])))
    # println(ne(topgraph))
    # reduciblepaths = Paths.get_reducible_paths_yen(topgraph, Symbol(intent["src"]), Symbol(intent["dst"]), 1000)
    # reduciblepaths = Paths.get_reducible_paths_yen(delaygraph, Symbol(intent["src"] * "_in"), Symbol(intent["dst"] * "_out"), 500)
    # println(size(reduciblepaths))
    # ProbTraversal.traversestatic(delaygraph, reduciblepaths, intent)
    # prob = ProbTraversal.traverse_topology_first(topgraph, intent)
    # println(prob)
end

if !isinteractive()
    main()
end

end # module
