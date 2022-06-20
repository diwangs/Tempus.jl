module ProbTraversal

using Combinatorics
import StatsBase
using Graphs
using MetaGraphsNext
using HypothesisTests

function traverse_static(g::AbstractGraph, paths::Vector{Vector{Symbol}}) 
    paths_combinations = collect(combinations(paths))

    p_property = 0.0
    for paths_combination in paths_combinations
        p_combination = 1.0

        # Calculate the probability of the components being up
        # Find unique links in the paths_combination
        links = [[(path[i], path[i+1]) for i=1:size(path)[1]-1] for path in paths_combination]
        # The line above assumes ordering is the same (e.g. :a, :b and not :b, :a)
        unique_links = unique(Iterators.flatten(links))
        p_combination = prod([g[src, dst]["prob"] for (src, dst) in unique_links])
        
        # Calculate the timing probability of a given combination
        # TODO: optimize this
        p_combination *= min([simulate_path_timing(g, path) for path in paths_combination]...)

        # Add this to the overall probability
        p_property += iseven(length(paths_combination)) ? -p_combination : p_combination
    end

    println(p_property)
end

# TODO: use this code to simulate pre-convergence state? Use AbstractState?
# Transient state & model definition
# Calculate the bounded probability assuming that the path don't fail
function simulate_path_timing(g::AbstractGraph, path::Vector{Symbol})::Float64
    mc_run::Int64 = 100000
    fail_count::Int64 = 0
    mc_run_count::Int64 = 0
    
    time_threshold::Float64 = 10000
    
    pair = [(path[i], path[i+1]) for i=1:size(path)[1]-1]

    for i=1:mc_run
        time_passed::Float64 = 0

        for (src, dst) in pair
            # pass t here for the src and dst
            g[src, dst]["time"] = time_passed
            # Check passed time
            time_passed += weights(g)[code_for(g, src), code_for(g, dst)]
            # Early stop if time threshold is surpassed
            if time_passed > time_threshold
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

            if rand() > g[src, dst]["prob"]
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