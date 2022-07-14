module ProbTraversal

using Combinatorics
import StatsBase
using Graphs
using MetaGraphsNext
using HypothesisTests
using Dates

function traverse_topology_first(topology_graph::AbstractGraph, intent::Dict{String, Any})::Float64
    p_explored = 0.0
    p_property = 0.0

    last_p_explored = p_explored
    # Dumb iteration for now
    for component_state in Base.product([[true, false] for i in 1:ne(topology_graph)]...)
        if p_explored > 0.999
            break
        end

        if p_explored - last_p_explored > 0.001
            println(Dates.Time(Dates.now()))
            println(p_explored)
            last_p_explored = p_explored
        end

        new_topology_graph = update_topology_graph(topology_graph, [i for i in component_state])
        
        # p_state = product of the topology
        p_state = (0.999 ^ count(x -> x, component_state)) * (0.001 ^ count(x -> !x, component_state))
        p_explored += p_state
        if has_path(new_topology_graph, code_for(new_topology_graph, Symbol(intent["src"])), code_for(new_topology_graph, Symbol(intent["dst"])))
            p_property += p_state # * P(D)
        end
    end

    return p_property
end

function update_topology_graph(topology_graph::AbstractGraph, state::Vector{Bool})
    # topology_graph is assumed to be all up
    new_topology_graph = copy(topology_graph)

    for (idx, edge) in enumerate(edges(topology_graph))
        if (!state[idx]) 
            rem_edge!(new_topology_graph, src(edge), dst(edge))
        end
    end

    return new_topology_graph
end

function traverse_path_first(g::AbstractGraph, reducible_paths::Vector{Vector{Symbol}}, intent::Dict{String, Any})::Float64
    p_property = 0.0
    for pathscom in combinations(reducible_paths)
        p_combination = 1.0

        # Calculate the probability of the components being up
        # The line below assumes ordering is the same (e.g. :a, :b and not :b, :a)
        links = [[(path[i], path[i+1]) for i=1:size(path)[1]-1] for path in pathscom]
        uniquelinks = unique(Iterators.flatten(links)) # Find unique links in the pathscom
        p_combination = prod([(1 - g[src, dst]["failProb"]) for (src, dst) in uniquelinks])

        # relevant_edges = []
        # for edge in edges(g)
        #     found = false
        #     for path in pathscom
        #         if found 
        #             break
        #         end
        #         for i in 1:size(path)[1]-1
        #             if found 
        #                 break
        #             end
        #             if code_for(g, path[i]) == src(edge) && code_for(g, path[i+1]) == dst(edge)
        #                 found = true
        #             end
        #         end
        #     end

        #     if found
        #         push!(relevant_edges, edge)
        #     end
        # end
        # p_combination = prod([(1 - g[label_for(src(e)), label_for(dst(e))]["failProb"]) for e in relevant_edges])
        
        # Calculate the timing probability of a given combination
        # TODO: optimize this with dynamic programming
        # p_combination *= min([simulate_path_delay(g, path, intent["threshold"]) for path in pathscom]...)

        # Add this to the overall probability
        p_property += iseven(length(pathscom)) ? -p_combination : p_combination
    end

    return p_property
end

# TODO: use this code to simulate pre-convergence state? Use AbstractState?
# Transient state & model definition
# Calculate the bounded probability assuming that the path don't fail
function simulate_path_delay(g::AbstractGraph, path::Vector{Symbol}, threshold::Float64)::Float64
    # TODO: replace this with confidence interval? But this is not Bernouli?
    mc_run::Int64 = 1
    fail_count::Int64 = 0
    mc_run_count::Int64 = 0
    
    pair = [(path[i], path[i+1]) for i=1:size(path)[1]-1]

    for i=1:mc_run
        time_passed::Float64 = 0

        for (src, dst) in pair
            # pass t here for the src and dst
            g[src, dst]["time"] = time_passed
            # Check passed time
            time_passed += weights(g)[code_for(g, src), code_for(g, dst)]
            # Early stop if time threshold is surpassed
            if time_passed > threshold
                fail_count += 1
                break
            end
        end
    end
    
    # Two intervals: epsilon and alpha
    # Epsilon -> increase the simulation count
    # Alpha -> increase the confidence level
    # return StatsBase.confint(BinomialTest(mc_run - fail_count, mc_run), level=0.95) # ignore p in BinomialTest
    return (mc_run - fail_count) / mc_run

end

# outputs the possible paths in the graph model (not in the network -> node = graph node != routers)
# DON'T USE, COMPUTATIONALLY NOT SCALABLE
# function getpaths(g::AbstractGraph, src::Symbol, dst::Symbol)::Vector{Vector{Symbol}}
#     paths = []

#     # Do DFS
#     function dfs(currentHop::Symbol, currentPath::Vector{Any}, visited::Vector{Any})
#         if currentHop in visited
#             return
#         end
        
#         # push both the router's in and out graph node
#         push!(visited, currentHop)
#         push!(currentPath, currentHop)
#         # push!(currentPath, Symbol(currentHop * "_out"))
        
#         if currentHop == dst
#             push!(paths, currentPath)
#             return
#         end

#         for nextHop in outneighbors(g, code_for(g, currentHop))
#             dfs(label_for(g, nextHop), copy(currentPath), copy(visited))
#         end
#     end

#     dfs(src, [], [])
#     return paths
# end

# function traverse_dynamic(g::AbstractGraph, fwd::Vector{Vector{Any}})
#     mc_run::Int64 = 100000
#     fail_count::Int64 = 0
#     mc_run_count::Int64 = 0
    
#     time_threshold::Float64 = 10000

#     for i=1:mc_run
#         time_passed::Float64 = 0
#         src::Symbol = :a

#         while src != :d
#             # ECMP: choose random hop
#             dst::Symbol = StatsBase.sample(fwd[code_for(g, src)])

#             if rand() < g[src, dst]["failProb"]
#                 fail_count += 1
#                 # Simulate routing protocols packet here
#                 break
#             end
            
#             # pass t here for the src and dst
#             g[src, dst]["time"] = time_passed
            
#             # Check passed time
#             time_passed += weights(g)[code_for(g, src), code_for(g, dst)]
            
#             # Early stop if time threshold is surpassed
#             if time_passed > time_threshold
#                 fail_count += 1
#                 break
#             end

#             src = dst
#         end
#     end

#     println((mc_run - fail_count) / mc_run)
# end

end # module