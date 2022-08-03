module ModifiedYen

# using TopologyGraphs
using Graphs
using MetaGraphsNext
using DataStructures
using Random

include("StateTrees.jl")

mutable struct MetaPath
    path::Vector{Symbol}
    dependencies::Vector{Symbol}        # TODO: technically should be a set
end

function tempus_yen(tg::AbstractGraph, src::Symbol, dst::Symbol)::Float64
    # If src and dst are the same node
    src == dst && return 1.0

    # Compute shortest path 
    path::Vector{Symbol} = dijkstra_symbol(tg, src, dst)
    isempty(path) && return 0.0 # not topologically connected

    # Create state tree
    st = StateTrees.StateTree()
    perfect = StateTrees.State([], [], 1)
    st[:perfect] = perfect

    # Create Yen's data structure
    A::Vector{MetaPath} = [MetaPath(path, [:perfect])]
    B = PriorityQueue()
    tgcopy = deepcopy(tg)

    p_explored::Float64 = 0.9^(length(path)-1)
    println("Y: Explored: $p_explored")
    p_property::Float64 = 0.9^(length(path)-1)

    # Yen's loop
    k::UInt = 1
    sc::UInt = 1
    while true
        mp::MetaPath = A[k]
        # p_property += 0.9^(length(mp.path)-1) * sum([StateTrees.p_dependency(st, s) for s in mp.dependencies])
        println(mp.path)

        for d::Symbol in mp.dependencies
            for spur_node_idx = st[d].spur_node_idx:length(mp.path)-1
                # Step 1: fail spur_node+1 link and its state dependencies
                spur_node::Symbol = mp.path[spur_node_idx]
                root_path::Vector{Symbol} = mp.path[1:spur_node_idx]
                failing_link::Tuple{Symbol, Symbol} = (mp.path[spur_node_idx], mp.path[spur_node_idx+1])
                disabled_links::Vector{Tuple{Symbol, Symbol}} = [failing_link; StateTrees.get_disabled_with_dep(st, d)]
                for (u, v) in disabled_links
                    rem_edge!(tgcopy, code_for(tgcopy, u), code_for(tgcopy, v))
                end

                # Step 2: calculate spur_path
                # disable links connected to root path node to prevent loops
                disabled_root_links::Vector{Tuple{Symbol, Symbol}} = []
                for u in root_path[1:length(root_path)-1]
                    for v in neighbors(tgcopy, code_for(tg, u))
                        rem_edge!(tgcopy, code_for(tgcopy, u), v)
                        push!(disabled_root_links, (u, label_for(tg, v)))
                    end
                end
                # compute shortest path from spur_node to dst
                spur_path::Vector{Symbol} = dijkstra_symbol(tgcopy, spur_node, dst)
                # reinsert disabled links
                for (u, v) in disabled_root_links
                    tgcopy[u, v] = 1.0
                end
                
                # Step 3: calculate total_path
                # Calculate state
                fe = [(root_path[i], root_path[i+1]) for i in st[d].spur_node_idx:length(root_path)-1]
                dis = [failing_link]
                s = StateTrees.State(fe, dis, isempty(spur_path) ? 1 : spur_node_idx)
                l::Symbol = Symbol(randstring(6)) # TODO: change this to something else that make sense
                st[l] = s
                st[d, l] = nothing
                p_functional_dependency::Float64 = StateTrees.p_dependency(st, l)

                # Calculate total path
                total_path::Vector{Symbol} = isempty(spur_path) ? dijkstra_symbol(tgcopy, src, dst) : [root_path[1:length(root_path)-1]; spur_path]
                if isempty(total_path)  
                    p_explored += p_functional_dependency
                    sc += 1
                    println("$sc (N): Explored: $p_explored")
                    continue # not reachable
                end

                # If reachable, calculate probability
                p_functional_path::Float64 = isempty(spur_path) ? 0.9^(length(total_path) - 1) : 0.9^(length(spur_path) - 1)
                p_explored += p_functional_path * p_functional_dependency
                sc += 1
                println("$sc (Y): Explored: $p_explored")
                println("Resulting in: $total_path")
                p_property += p_functional_path * p_functional_dependency

                # check if tot_path is in B
                mp_tp_set = filter(x -> x.path == total_path, keys(B))
                if length(mp_tp_set) == 0
                    B[MetaPath(total_path, [l])] = length(total_path) # WRONG!
                else
                    for mp_tp in mp_tp_set # set element can't be individually addressed
                        push!(mp_tp.dependencies, l)
                    end
                end

                # Restore tg_copy
                for (u, v) in disabled_links
                    tgcopy[u, v] = 1.0
               end
            end
        end
        
        isempty(B) && break
        push!(A, dequeue!(B))
        k += 1
    end

    println("Reachable: $p_property")
    return p_property
end

function dijkstra_symbol(g::AbstractGraph, src::Symbol, dst::Symbol)::Vector{Symbol}
    dj = dijkstra_shortest_paths(g, code_for(g, src))
    path_code = enumerate_paths(dj)[code_for(g, dst)]
    return [label_for(g, x) for x in path_code]
end

end # module