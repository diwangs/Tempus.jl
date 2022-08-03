module StateTrees

using Graphs
using MetaGraphsNext

struct State 
    force_enabled::Vector{Tuple{Symbol, Symbol}}
    disabled::Vector{Tuple{Symbol, Symbol}}
    spur_node_idx::UInt # this state shares the same root_path with its parent up until this index (1 == only shares src)
end

const StateTree = typeof(MetaGraph(DiGraph(), VertexData = State))
StateTree() = MetaGraph(DiGraph(), VertexData = State)

function get_disabled_with_dep(st::StateTree, l::Symbol)::Vector{Tuple{Symbol, Symbol}}
    disabled_with_dep::Vector{Tuple{Symbol, Symbol}} = [st[l].disabled...]
    
    # If it's root state, return with current vector
    parents::Vector{Int} = inneighbors(st, code_for(st, l))
    length(parents) == 0 && return disabled_with_dep

    # else
    parent::Symbol = label_for(st, parents[1]) # tree node only have one parent
    disabled_with_dep = [disabled_with_dep; get_disabled_with_dep(st, parent)]

    return disabled_with_dep
end

function p_dependency(st::StateTree, l::Symbol)::Float64
    # Check if s is in st
    
    p_state::Float64 = 1.0
    # TODO: a TopologyGraph later to get failure and success rate
    success_cnt::UInt = length(st[l].force_enabled)
    fail_cnt::UInt = length(st[l].disabled)
    p_state *= 0.9^success_cnt * 0.1^fail_cnt

    # If it's root state, return with current probability
    parents::Vector{Int} = inneighbors(st, code_for(st, l))
    length(parents) == 0 && return p_state

    # If it's not root state, do recursion
    parent::Symbol = label_for(st, parents[1]) # tree node only have one parent
    p_state *= p_dependency(st, parent)

    return p_state
end

end # module