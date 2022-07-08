module Paths

using Graphs
using MetaGraphsNext

function get_reducible_paths_yen(g::AbstractGraph, src::Symbol, dst::Symbol, K::Int)::Vector{Vector{Symbol}}
     yen = yen_k_shortest_paths(g.graph, code_for(g, src), code_for(g, dst), weights(g), K)
     reducible_paths::Vector{Vector{Symbol}} = []
     for path in yen.paths
         labeled_path = map((x) -> label_for(g, x), path)
         push!(reducible_paths, labeled_path)
     end
     return reducible_paths
end

end # module