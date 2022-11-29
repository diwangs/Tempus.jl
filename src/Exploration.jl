mutable struct MetaPath
    path::Vector{Symbol}
    dependencies::Vector{Symbol}        # TODO: technically should be a set
end

function explore(tg::AbstractGraph, src::Symbol, dst::Symbol, threshold::Real)::Float64
    start = now()

    # If src and dst are the same node
    src == dst && return 1.0

    # Create state tree and exploration queue
    st = StateTree()
    e = PriorityQueue(Base.Order.Reverse)

    # Create the perfect state as the initial state
    perfect = State([], [])
    st[:perfect] = perfect
    st[:perfect].p_state = get_p_state(tg, st, :perfect)
    e[:perfect] = st[:perfect].p_state
    
    # Prepare for functional state exploration
    tgcopy = deepcopy(tg)
    p_explored = 0.0

    # Explore functional state
    cnt = 0
    while !isempty(e) && p_explored < 0.99999999
        cnt += 1
        l = dequeue!(e)

        # Disable links of this current state
        # offlinks is undirected, offlinksdata is directed
        offlinks::Vector{Tuple{Symbol, Symbol}} = get_disabled_with_dep(st, l)
        offlinksdata = Dict{Tuple{Symbol, Symbol}, Tuple{Real, Distribution, Distribution, UInt}}()
        for (u, v) in offlinks
            offlinksdata[(u, v)] = tgcopy[u, v]
            rem_edge!(tgcopy, code_for(tgcopy, u), code_for(tgcopy, v))
            offlinksdata[(v, u)] = tgcopy[v, u]
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
            st[lc].p_state = get_p_state(tg, st, lc)
            
            e[lc] = st[lc].p_state
        end

        # Update the explored probability
        hot_edges_new_prob = !isempty(hot_edges_new) ? prod([1 - first(tgcopy[u, v]) for (u, v) in hot_edges_new]) : 1.0
        st[l].p_paths_functional = !isempty(hot_edges) ? hot_edges_new_prob : 0.0
        p_explored += !isempty(hot_edges) ? st[l].p_state * st[l].p_paths_functional : st[l].p_state
        println(p_explored)

        # Restore disabled links for next state exploration
        for (key, val) in offlinksdata
            tgcopy[key[1], key[2]] = val
        end
    end
    println(now() - start)

    # Calculate p_paths_temporal of all states
    start = now()
    p_paths_temporals = Dict{Set{Vector{Symbol}}, Float64}()
    p_path_temporals = Dict{Vector{Symbol}, Float64}()
    cnt_reexploration = 0
    cnt_path = 0
    cnt_aconv = 0
    cnt_nconv = 0
    for x in map(y -> label_for(st, y), vertices(st))
        isempty(st[x].converged_paths) && continue

        # If p_paths_temporal has not been computed before, re-explore state
        if !haskey(p_paths_temporals, Set{Vector{Symbol}}(st[x].converged_paths))
            # Compute probability of each path being taken
            weights = ecmpprob(st[x].converged_paths)

            # Compute p_paths_temporal from weighted p_path_temporal
            p_paths_temporal = 0.0
            for path in st[x].converged_paths
                # If p_path_temporal has not been computed before, do convolutions
                if !haskey(p_path_temporals, path)
                    # Do convolution
                    d, lcnt_aconv, lcnt_nconv = pathdist_unopt(path, tg)
                    cnt_aconv += lcnt_aconv
                    cnt_nconv += lcnt_nconv
                    
                    # Check temporal property based on path latency distribution d
                    # For now, it's just bounded reachability
                    p_path_temporals[path] = cdf(d, threshold)
                    cnt_path += 1
                end

                p_paths_temporal += weights[path] * p_path_temporals[path]
                # delete!(p_path_temporals, path)
            end

            p_paths_temporals[Set{Vector{Symbol}}(st[x].converged_paths)] = p_paths_temporal
            cnt_reexploration += 1
        end
        
        # If p_paths_temporal has been computed before, then just use that
        st[x].p_paths_temporal = p_paths_temporals[Set{Vector{Symbol}}(st[x].converged_paths)]
        # delete!(p_paths_temporals, Set{Vector{Symbol}}(st[x].converged_paths))
    end
    println(now() - start)

    # Print some debug status
    println("Amount of state explored ", cnt)
    println("Amount of state re-explored ", cnt_reexploration)
    println("Amount of unique path ", cnt_path)
    println("Amount of convolutions ", cnt_aconv)
    println("Amount of convolutions ", cnt_nconv)
    println("Avg conv / path ", (cnt_aconv + cnt_nconv) / cnt_path)

    # Calculate bounded reachability
    p_property = sum([st[x].p_state * st[x].p_paths_functional * st[x].p_paths_temporal for x in map(y -> label_for(st, y), vertices(st))])

    return p_property
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

# Given a path and topology graph, what is the latency distribution of that path
function pathdist_unopt(path::Vector{Symbol}, tg::TopologyGraph)::Tuple{Distribution, UInt, UInt}
    lcnt_conv = 0
    
    links = path_to_links(path)
    d = nothing

    for link in links
        if d == nothing 
            d = convolve(tg[link[1], link[2]][2], tg[link[1], link[2]][3])
            lcnt_conv += 1
        else
            # println(typeof(d), typeof(tg[link[1], link[2]][2]))
            d = convolve(d, tg[link[1], link[2]][2])
            d = convolve(d, tg[link[1], link[2]][3])
            lcnt_conv += 2
        end
    end

    return (d, lcnt_conv, 0)
end

function pathdist(path::Vector{Symbol}, tg::TopologyGraph)::Tuple{Distribution, UInt, UInt}
    lcnt_aconv = 0
    lcnt_nconv = 0
    
    links = path_to_links(path)
    g = Dict{DataType, Distribution}()

    # Group similar distribution
    # TODO: whitelist instead of relying on type
    # TODO: smarter convolution between exponential and gamma
    for link in links
        t = tg[link[1], link[2]][2]
        if !haskey(g, typeof(t))
            g[typeof(t)] = t
        else
            g[typeof(t)] = convolve(t, g[typeof(t)])
            lcnt_aconv += 1
        end

        t = tg[link[1], link[2]][3]
        if !haskey(g, typeof(t))
            g[typeof(t)] = t
        else
            g[typeof(t)] = convolve(t, g[typeof(t)])
            lcnt_aconv += 1
        end
    end

    # analytically convolve each group
    a = values(g)
    # for group in values(g)
    #     d = nothing
    #     for dist in group 
    #         if d == nothing 
    #             d = dist
    #         else
    #             d = convolve(d, dist)
    #             lcnt_aconv += 1
    #         end
    #     end

    #     if typeof(d) == DirectDistribution{Float64}
    #         pushfirst!(a, d)
    #     else 
    #         push!(a, d)
    #     end
    # end

    # numerically convolve 
    d = nothing
    for dist in a
        if d == nothing 
            d = dist
        else
            d = convolve(d, dist)
            lcnt_nconv += 1
        end
    end

    return (d, lcnt_aconv, lcnt_nconv)
end