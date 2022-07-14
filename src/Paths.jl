module Paths

using Graphs
using MetaGraphsNext

function get_reducible_paths_yen(g::AbstractGraph, src::Symbol, dst::Symbol, K::Int)::Vector{Vector{Symbol}}
     yen = yen_k_shortest_paths(g.graph, code_for(g, src), code_for(g, dst), weights(g), K)
     reduciblepaths::Vector{Vector{Symbol}} = map(x -> map(x_i -> label_for(g, x_i), x), yen.paths)
     return reduciblepaths
end

end # module