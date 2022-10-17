mutable struct State 
    # Pre-exploration
    force_enabled::Vector{Tuple{Symbol, Symbol}}
    disabled::Vector{Tuple{Symbol, Symbol}}
    spur_node_idx::UInt # this state shares the same root_path with its parent up until this index (1 == only shares src)
    
    # Post-exploration
    converged_paths::Vector{Vector{Symbol}}
    p_state::Float64                            # The probability of the network arriving at this state (hot edges of this state and its predecesors)
    p_paths_functional::Float64                 # The probability of _new_ hot edges being up (converged_paths - (force_enabled + disabled))
                                                # 1.0 == no new hot edges, 0.0 == not reachable

    # Post-grouping
    p_paths_temporal::Float64                   # The probability of converged_paths transmitting packets below a threshold

    State(force_enabled, disabled, spur_node_idx::Int) = new(force_enabled, disabled, spur_node_idx, [], 0.0, 0.0, 0.0)
    State(force_enabled, disabled) = new(force_enabled, disabled, 1, [], 0.0, 0.0, 0.0)
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

function get_enabled_with_dep(st::StateTree, l::Symbol)::Vector{Tuple{Symbol, Symbol}}
    disabled_with_dep::Vector{Tuple{Symbol, Symbol}} = [st[l].force_enabled...]
    
    # If it's root state, return with current vector
    parents::Vector{Int} = inneighbors(st, code_for(st, l))
    length(parents) == 0 && return disabled_with_dep

    # else
    parent::Symbol = label_for(st, parents[1]) # tree node only have one parent
    disabled_with_dep = [disabled_with_dep; get_enabled_with_dep(st, parent)]

    return disabled_with_dep
end

function get_p_state(st::StateTree, l::Symbol)::Float64
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
    p_state *= get_p_state(st, parent)

    return p_state
end