module ProbTraversal

using Combinatorics
import StatsBase
using Graphs
using MetaGraphsNext
using HypothesisTests

function traversestatic(g::AbstractGraph, fwdtable::Dict{String, Any}, intent::Dict{String, Any})::Float64
    paths::Vector{Vector{Symbol}} = getpaths(fwdtable, intent["src"], intent["dst"])
    # Get paths from src, dst, and forwarding table
    
    pathscoms = collect(combinations(paths))

    p_property = 0.0
    for pathscom in pathscoms
        p_combination = 1.0

        # Calculate the probability of the components being up
        # Find unique links in the pathscom
        links = [[(path[i], path[i+1]) for i=1:size(path)[1]-1] for path in pathscom]
        # The line above assumes ordering is the same (e.g. :a, :b and not :b, :a)
        uniquelinks = unique(Iterators.flatten(links))
        p_combination = prod([(1 - g[src, dst]["failProb"]) for (src, dst) in uniquelinks])
        
        # Calculate the timing probability of a given combination
        # TODO: optimize this (dynamic programming)
        p_combination *= min([simulate_path_delay(g, path, intent["threshold"]) for path in pathscom]...)

        # Add this to the overall probability
        p_property += iseven(length(pathscom)) ? -p_combination : p_combination
    end

    return p_property
end

# outputs the possible paths in the graph model (not in the network -> node = graph node != routers)
function getpaths(fwdtable::Dict{String, Any}, src::String, dst::String)::Vector{Vector{Symbol}}
    paths = []

    # Do DFS
    function dfs(currentHop::String, currentPath::Vector{Any})
        # push both the router's in and out graph node
        push!(currentPath, Symbol(currentHop * "_in"))
        push!(currentPath, Symbol(currentHop * "_out"))
        
        if currentHop == dst
            push!(paths, currentPath)
            return
        end

        for nextHop in fwdtable[currentHop][dst]
            nextPath = copy(currentPath)
            dfs(nextHop, nextPath)
        end
    end

    dfs(src, [])
    return paths
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

function traverse_dynamic(g::AbstractGraph, fwd::Vector{Vector{Any}})
    mc_run::Int64 = 100000
    fail_count::Int64 = 0
    mc_run_count::Int64 = 0
    
    time_threshold::Float64 = 10000

    for i=1:mc_run
        time_passed::Float64 = 0
        src::Symbol = :a

        while src != :d
            # ECMP: choose random hop
            dst::Symbol = StatsBase.sample(fwd[code_for(g, src)])

            if rand() < g[src, dst]["failProb"]
                fail_count += 1
                # Simulate routing protocols packet here
                break
            end
            
            # pass t here for the src and dst
            g[src, dst]["time"] = time_passed
            
            # Check passed time
            time_passed += weights(g)[code_for(g, src), code_for(g, dst)]
            
            # Early stop if time threshold is surpassed
            if time_passed > time_threshold
                fail_count += 1
                break
            end

            src = dst
        end
    end

    println((mc_run - fail_count) / mc_run)
end

end # module