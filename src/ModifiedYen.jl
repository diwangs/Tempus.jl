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
    path::Vector{Symbol} = dijkstra_mg(tg, src, dst)
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
    println("1: explored: $p_explored")
    p_property::Float64 = 0.9^(length(path)-1)

    # Yen's loop
    k::UInt = 1
    sc::UInt = 1
    while true
        mp::MetaPath = A[k]
        # p_property += 0.9^(length(mp.path)-1) * sum([StateTrees.get_p_state(st, s) for s in mp.dependencies])
        println("Exploring: $(mp.path)")

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
                # # disable links connected to root path node to prevent loops
                # disabled_root_links::Vector{Tuple{Symbol, Symbol}} = []
                # for u in root_path[1:length(root_path)-1]
                #     for v in neighbors(tgcopy, code_for(tg, u))
                #         rem_edge!(tgcopy, code_for(tgcopy, u), v)
                #         push!(disabled_root_links, (u, label_for(tg, v)))
                #     end
                # end
                # # compute shortest path from spur_node to dst
                # spur_path::Vector{Symbol} = dijkstra_mg(tgcopy, spur_node, dst)
                # # reinsert disabled links
                # for (u, v) in disabled_root_links
                #     tgcopy[u, v] = 1.0
                # end
                spur_path::Vector{Symbol} = []
                
                # Step 3: calculate total_path
                # Calculate state
                fe = [(root_path[i], root_path[i+1]) for i in st[d].spur_node_idx:length(root_path)-1]
                dis = [failing_link]
                s = StateTrees.State(fe, dis, isempty(spur_path) ? 1 : spur_node_idx)
                l::Symbol = Symbol(randstring(6)) # TODO: change this to something else that make sense
                st[l] = s
                st[d, l] = nothing
                p_state::Float64 = StateTrees.get_p_state(st, l)

                # Calculate total path
                total_path::Vector{Symbol} = isempty(spur_path) ? dijkstra_mg(tgcopy, src, dst) : [root_path[1:length(root_path)-1]; spur_path]
                # Restore tg_copy
                for (u, v) in disabled_links
                    tgcopy[u, v] = 1.0
                end
                sc += 1
                if isempty(total_path) # not reachable
                    p_explored += p_state
                    println("$sc: explored: $disabled_links $p_explored")
                    if p_explored > 0.99999
                        println("Reachable: $p_property")
                        return p_property
                    end
                    continue 
                end

                # If reachable, calculate probability
                p_functional_path::Float64 = isempty(spur_path) ? 0.9^(length(total_path) - 1) : 0.9^(length(spur_path) - 1)
                p_explored += p_functional_path * p_state
                p_property += p_functional_path * p_state
                println("$sc: explored: $disabled_links $p_explored")
                if p_explored > 0.99999
                    println("Reachable: $p_property")
                    return p_property
                end
                
                # check if tot_path is in B
                println("enqueuing: $total_path")
                mp_tp_set = filter(x -> x.path == total_path, keys(B))
                if length(mp_tp_set) == 0
                    B[MetaPath(total_path, [l])] = length(total_path)
                else
                    for mp_tp in mp_tp_set # set element can't be individually addressed
                        push!(mp_tp.dependencies, l)
                    end
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

function tempus_yen_stateful(tg::AbstractGraph, src::Symbol, dst::Symbol)::Float64
    # If src and dst are the same node
    src == dst && return 1.0

    # Create state tree and exploration queue
    st = StateTrees.StateTree()
    e = PriorityQueue(Base.Order.Reverse)

    # Create the perfect state as the initial state
    perfect = StateTrees.State([], [])
    st[:perfect] = perfect
    st[:perfect].p_state = StateTrees.get_p_state(st, :perfect)
    e[:perfect] = st[:perfect].p_state
    
    # Prepare for functional state exploration
    tgcopy = deepcopy(tg)
    p_explored = 0.0
    # p_property = 0.0

    # Explore functional state
    cnt = 0
    while !isempty(e)
        cnt += 1
        l = dequeue!(e)

        # Disable links of this current state
        disabled_links::Vector{Tuple{Symbol, Symbol}} = StateTrees.get_disabled_with_dep(st, l)
        for (u, v) in disabled_links
            rem_edge!(tgcopy, code_for(tgcopy, u), code_for(tgcopy, v))
        end

        # Based on the current network state, compute hot edges (right now it's equal cost shortest paths)
        st[l].converged_paths = dijkstra_mg_allpaths(tgcopy, src, dst)
        hot_edges = allpaths_to_unique_links(st[l].converged_paths)
        force_enabled_links::Vector{Tuple{Symbol, Symbol}} = StateTrees.get_enabled_with_dep(st, l)
        hot_edges_new = filter(x -> !((x[1], x[2]) in force_enabled_links || (x[2], x[1]) in force_enabled_links), hot_edges)

        # Enqueue new state based on (new) hot edges, with its p_state as prioritization
        for i in 1:length(hot_edges_new)
            # NOTE: this is different from NetDice's p_state, since it doesn't contain the shortest paths probability
            s = StateTrees.State(hot_edges_new[1:i-1], [hot_edges_new[i]], 1)
            lc::Symbol = Symbol(randstring(10)) # TODO: change this to something else that make sense
            st[lc] = s
            st[l, lc] = nothing
            st[lc].p_state = StateTrees.get_p_state(st, lc)
            
            e[lc] = st[lc].p_state
        end

        # Update the explored probability
        st[l].p_paths_functional = !isempty(hot_edges) ? 0.9^length(hot_edges_new) : 0.0
        p_explored += !isempty(hot_edges) ? st[l].p_state * st[l].p_paths_functional : st[l].p_state
        println(p_explored)

        # Restore disabled links for next state exploration
        for (u, v) in disabled_links
            tgcopy[u, v] = 1.0
        end
    end

    # Calculate p_paths_temporal of this state
    p_path_temporals = Dict{Vector{Symbol}, Float64}()
    for x in map(y -> label_for(st, y), vertices(st))
        isempty(st[x].converged_paths) && continue

        p_paths_temporals = Vector{Float64}()
        for path in st[x].converged_paths
            if !haskey(p_path_temporals, path)
                p_path_temporals[path] = 1.0 # Replace this with simulation
            end
            p_paths_temporals = [p_paths_temporals; p_path_temporals[path]]
        end

        st[x].p_paths_temporal = min(p_paths_temporals...) # Infimum?
    end

    # Calculate bounded reachability
    p_property = sum([st[x].p_state * st[x].p_paths_functional * st[x].p_paths_temporal for x in map(y -> label_for(st, y), vertices(st))])

    return p_property
end

function dijkstra_mg(g::AbstractGraph, src::Symbol, dst::Symbol)::Vector{Symbol}
    dj = dijkstra_shortest_paths(g, code_for(g, src))
    path_code = enumerate_paths(dj, code_for(g, dst))
    return [label_for(g, x) for x in path_code]
end

function dijkstra_mg_allpaths(g::AbstractGraph, src::Symbol, dst::Symbol)::Vector{Vector{Symbol}}
    dj = dijkstra_shortest_paths(g, code_for(g, src), allpaths=true)
    paths_code = enumerate_all_paths(dj.predecessors, code_for(g, src), code_for(g, dst))
    return [[label_for(g, x) for x in path_code] for path_code in paths_code]
end

function enumerate_all_paths(preds::Vector{Vector{Int}}, src::Int, v::Int, allpaths::Vector{Vector{Int}})::Vector{Vector{Int}}
    # Base case
    if preds[v] == Int[] && v == src
        return [[v; allpath] for allpath in allpaths]
    end

    # DFS recursive case
    new_allpaths = []
    for parent in preds[v]
        push!(new_allpaths, enumerate_all_paths(preds, src, parent, [[v; allpath] for allpath in allpaths])...)
    end
    return new_allpaths
end

enumerate_all_paths(preds::Vector{Vector{Int}}, src::Int, v::Int) = enumerate_all_paths(preds, src, v, Vector{Int}[Int[]])

function path_to_links(path::Vector{Symbol})::Vector{Tuple{Symbol, Symbol}}
    return [(path[i], path[i+1]) for i in 1:length(path)-1]
end

function allpaths_to_unique_links(allpaths::Vector{Vector{Symbol}})::Vector{Tuple{Symbol, Symbol}}
    links::Vector{Tuple{Symbol, Symbol}} = []
    for path in allpaths
        push!(links, path_to_links(path)...)
    end
    return unique(links)
end

end # module