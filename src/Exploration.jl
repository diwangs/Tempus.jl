mutable struct MetaPath
    path::Vector{Symbol}
    dependencies::Vector{Symbol}        # TODO: technically should be a set
end

function explore(tg::AbstractGraph, src::Symbol, dst::Symbol)::Float64
    # If src and dst are the same node
    src == dst && return 1.0

    # Create state tree and exploration queue
    st = StateTree()
    e = PriorityQueue(Base.Order.Reverse)

    # Create the perfect state as the initial state
    perfect = State([], [])
    st[:perfect] = perfect
    st[:perfect].p_state = get_p_state(st, :perfect)
    e[:perfect] = st[:perfect].p_state
    
    # Prepare for functional state exploration
    tgcopy = deepcopy(tg)
    p_explored = 0.0

    # Explore functional state
    cnt = 0
    while !isempty(e)
        cnt += 1
        l = dequeue!(e)

        # Disable links of this current state
        disabled_links::Vector{Tuple{Symbol, Symbol}} = get_disabled_with_dep(st, l)
        for (u, v) in disabled_links
            rem_edge!(tgcopy, code_for(tgcopy, u), code_for(tgcopy, v))
            rem_edge!(tgcopy, code_for(tgcopy, v), code_for(tgcopy, u))
        end

        # Based on the current network state, compute hot edges (right now it's equal cost shortest paths)
        st[l].converged_paths = dijkstra_mg_allpaths(tgcopy, src, dst)
        hot_edges = allpaths_to_unique_links(st[l].converged_paths)
        force_enabled_links::Vector{Tuple{Symbol, Symbol}} = get_enabled_with_dep(st, l)
        hot_edges_new = filter(x -> !((x[1], x[2]) in force_enabled_links || (x[2], x[1]) in force_enabled_links), hot_edges)

        # Enqueue new state based on (new) hot edges, with its p_state as prioritization
        for i in 1:length(hot_edges_new)
            # NOTE: this is different from NetDice's p_state, since it doesn't contain the shortest paths probability
            s = State(hot_edges_new[1:i-1], [hot_edges_new[i]], 1)
            lc::Symbol = Symbol(randstring(10)) # TODO: change this to something else that make sense
            st[lc] = s
            st[l, lc] = nothing
            st[lc].p_state = get_p_state(st, lc)
            
            e[lc] = st[lc].p_state
        end

        # Update the explored probability
        st[l].p_paths_functional = !isempty(hot_edges) ? 0.9^length(hot_edges_new) : 0.0
        p_explored += !isempty(hot_edges) ? st[l].p_state * st[l].p_paths_functional : st[l].p_state
        println(p_explored)

        # Restore disabled links for next state exploration
        for (u, v) in disabled_links
            tgcopy[u, v] = (0.9, 1)
            tgcopy[v, u] = (0.9, 1)
        end
    end

    # Calculate p_paths_temporal of this state
    p_paths_temporals = Dict{Vector{Vector{Symbol}}, Float64}()
    p_path_temporals = Dict{Vector{Symbol}, Float64}()
    cnt_reexploration = 0
    cnt_conv = 0
    for x in map(y -> label_for(st, y), vertices(st))
        isempty(st[x].converged_paths) && continue

        # If p_paths_temporal has not been computed before, re-explore state
        if !haskey(p_paths_temporals, st[x].converged_paths)
            # Compute probability of each path being taken
            weights = ecmpprob(st[x].converged_paths)

            # Compute p_paths_temporal from weighted p_path_temporal
            p_paths_temporal = 0.0
            for path in st[x].converged_paths
                # If p_path_temporal has not been computed before, do convolutions
                if !haskey(p_path_temporals, path)
                    # TODO: convolution
                    p_path_temporals[path] = 1.0
                    cnt_conv += (length(path) - 1) * 2
                end

                p_paths_temporal += weights[path] * p_path_temporals[path]
            end

            p_paths_temporals[st[x].converged_paths] = p_paths_temporal
            cnt_reexploration += 1
        end

        # If p_paths_temporal has been computed before, then just use that
        st[x].p_paths_temporal = p_paths_temporals[st[x].converged_paths]
    end

    println("Amount of state explored ", cnt)
    println("Amount of state re-explored ", cnt_reexploration)
    println("Amount of convolutions ", cnt_conv)

    # Calculate bounded reachability
    p_property = sum([st[x].p_state * st[x].p_paths_functional * st[x].p_paths_temporal for x in map(y -> label_for(st, y), vertices(st))])

    return p_property
end

# function dijkstra_mg(g::AbstractGraph, src::Symbol, dst::Symbol)::Vector{Symbol}
#     dj = dijkstra_shortest_paths(g, code_for(g, src))
#     path_code = enumerate_paths(dj, code_for(g, dst))
#     return [label_for(g, x) for x in path_code]
# end

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

# Given a list of paths, what is the probability that a path would be chosen given random choice at a node?
function ecmpprob(paths::Vector{Vector{Symbol}})::Dict{Vector{Symbol}, Float64}
    probs = Dict{Vector{Symbol}, Float64}()
    # Count the links with unique src 
    uniquelinks = allpaths_to_unique_links(paths)

    # prob = product of 1 / count
    for path in paths
        links = path_to_links(path)
        prob = 1.0
        for link in links
            # Count the unique links with the same src 
            prob /= count(x -> first(x) == first(link), uniquelinks)
        end
        probs[path] = prob
    end

    return probs
end