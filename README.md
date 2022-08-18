# tempus.jl
Time-conscious Network Verifier

How To Run: install Julia (tested on 1.7.3) and run the following command:
```bash
julia --project=. src/Tempus.jl
```

# Encoding
- Network is modeled as double-weighted undirected graph
    - Weight == delay, sampled from a distribution
- Encoded in Julia as edge-weighted directed graph
    - Double-weighted graph -> edge-weighted directed graph
- Weights via MetaGraph weight function

# Property Verification
- Bounded reachability:
    - Given:
        - Topology
        - src-dst pair
        - Failure rate of components -> failure scenarios (subset of links)
        - Routing protocol
    - Compute the probability of packets coming from src arrives at dst in under T time unit
- __Paths__ will be the primary unit of reasoning to determine the propagation delay of a packet
    - Delay of a given packet directly depends on the path it traverse
        - Since delay is causal (total delay of a packet at a given point in time depends on the previous component they traverse)
    - The path it traverse depends on the forwarding graph
        - For a given _forwarding table_ and _source-destination pair_, we can enumerate legible _paths_
        - Can take multiple equally-probable path (e.g. ECMP)
    - Forwarding graph depends on the routing protocol

## Single-Path
- __Assumptions__: 
    - Let there be a _topology_ and _src-dst pair_ (arbitrary routing protocol and component failure)
    - src-dst pair only has one possible path
    - e.g. static routing, dynamic routing of path graph network 
- __Reachability Definition__: Reachable (`reachable_sp`) iff the components in the path are up (`path_functional`) AND the path's theoretical propagation delay is below T (`path_temporal`)
- `P(reachable_sp) = P(path_functional, path_temporal)`
- "Theoretical" -> based on the model, assuming that the relevant components are up
- Independent: `P(path_functional, path_temporal) = P(path_functional) P(path_temporal)`
- `P(path_functional)`: computed analytically
    - Sample space: the status of all components in the path (e.g. {up, up, down}, etc.)
    - Probability function: product of the probability of the components being in that state (0.9 * 0.9 * 0.1)
- `P(path_temporal)`: computed numerically -> use distribution sample (simulation) to estimate population
    - Simulate the packet propagation
        - Iterate through each components, sample its delay, add them
        - Each components have a certain distribution / change with time
        - Either save the total in a buffer (make it available for plotting) or do early stopping 
    - Sample space: yes or no 
        - But not a bernoulli process, since dynamic queuing delay makes it not IID?
    - Probability function = run below T / total run
    - Special case when distributions are the same: convolution

## Reducible Multi-Paths
- Relax the assumption of single path
- __Assumptions__:
    - Let there be a _topology_ and _src-dst pair_ (arbitrary routing protocol and component failure)
    - src-dst pair can have multiple possible paths, represented by `path_list`
    - `path_list` is _reducible_ -> across all failure scenarios, the routing protocol won't add _new_ paths to the list
        - Let `convergent_path_list` be the paths that a packet will take under one particular failure scenario and a routing protocol
        - `path_list` can be thought of a generalization of `convergent_path_list`, the list of path across _all_ failure scenario and routing protocol
    - e.g. static routing with ECMP, dynamic routing with certain restricted topology (e.g. ecmp2)
        - Scenario when `convergent_path_list` == `path_list`
- __Reachability Definition__: Reachable (`reachable_mp`) iff one of the path is reachable (`reachable_sp_1`, `reachable_sp_2`, ...)
- Example for 2 paths: `P(reachable_mp) = P(reachable_sp_1 OR reachable_sp_2)`
    - Additive rule: `P(reachable_sp_1 OR reachable_sp_2) = P(reachable_sp_1) + P(reachable_sp_2) - P(reachable_sp_1, reachable_sp_2)`
    - Conjunctive reachability -> not independent: `P(reachable_sp_1, reachable_sp_2) != P(reachable_sp_1) P(reachable_sp_2)`, they might share links
- __Conjunctive Reachability Definition__: Reachable from all paths (`paths_reachable_mp`) iff the components in all paths are up (`paths_functional_mp`) AND all path's theoretical propagation delay is below T (`paths_temporal`)
- `P(paths_functional_mp)`: same as single-path, but joint components only counted once
- `P(paths_temporal)`: the minimum of P(D1) and P(D2)? -> subject to further discussion
    - Infimum?
- __Approximating Dynamic Routing__:
    - In a dynamic routing on realistic network, they often have some unused redundant (often longer) path that will be used if some combination of components fail
        - Making the current `convergent_path_list` irreducible
    - Naive solution -> enumerate all paths to make the path list reducible
        - Enumerate all paths _accross changes in forwarding table_
        - Problem: intractable
            - We must compute the combination of all those paths to compute the conjunctive reachability for the additive rule -> factorial
            - Enumerating all paths in an arbitrary graph is NP-hard (#P-hard? See longest path problem)

## Dynamic Routing (post-convergence)
- Strengthen the assumption on routing protocol
- Solving 1st intractability: 
    - Old: using additive rules with the combination for all possible paths, given arbitrary component failure and routing protocols
    - New: iterate through all the network state, compute the `convergent_path_list` with a certain _routing protocol_, and add the probability
    - n links -> 2^n states iteration (brute force)
    - Factorial to exponential
- To solve the 2nd intractability, We must somehow efficiently iterate through all possible failures scenarios to compute the different `convergent_path_list`
    - NetDice!
    - State reduction: merging cold edges state ->  a set of links whose failure is provably guaranteed not to change whether property holds
        - `state` -> 2 tuple `(d, fe)`; `d` is a set of disabled links, `fe` is a set of links that is enabled and counted
        - Merging state: marginalizing probability of the set of links whose failure doesn't introduce new paths -> reducible
    - Prioritization: most probable state get explored first
        - Can early stop up to a certain level of precision
- __Assumptions__:
    - Let there be a _topology_ and _src-dst pair_
    - Given a _routing protocol_, src-dst pair can have multiple convergent paths (`convergent_path_list`), for arbitrary component failure
- __Reachability Definition__: Reachable (`reachable_dr`) iff under certain failure scenarios, the routing algorithm produces a convergent paths (`paths_reachable`)
- `P(reachable_dr) = sum([P(state) * P(paths_reachable)])` for all state where where src-dst is functionally reachable
    - `paths_reachable` is a small adjustment to `paths_reachable_mp`: the links on `state` and `paths_functional_mp` might overlap
        - `P(paths_functional)`: same as reducible multi-paths, but not including links in the current `state`
        - `P(paths_temporal)` is the exact same
    - `P(paths_reachable)` computes on the convergent paths calculated by the routing protocol

## TODO
- How should we approach `P(paths_temporal)`?
    - Given a list of paths `paths` (assumed to be alive), what is the probability that a packet _can_ traverse _all_ of them (conjunctive) under T time unit? 
    - Currently it's `min([P(path) for path in paths])`
        - Boolean case: consider the case that the path either can transmit packet under `T` 100% of the time (`true`) or 0% of the time (`false`)
            - If one of them is `false`, then its conjunction will also be `false`
        - Discrete simulation case: 
            - Consider `n` packets and 2 paths: `p1` and `p2`
            - Let those packets get transmitted exclusively through `p1`, the amount of packets received is denoted by `x < n`
            - Now, let those same packets get transmitted exclusively through `p2`, the amount of packets received is denoted by `y < n`
            - Conjunction: count the packets that gets successfully delivered under those two scenario
        - Geometric / continuous distribution case:
            - Each path has a probability distribution (`P(T)` to compute the probability)
            - Conjunction: given area under curve left of `T`, what is the total area shared by all of them? -> the minimum
- How do we represent imprecision?
    - NetDice (the functional part) has `p_explored`
        - Imprecision -> `1 - p_explored`
        - Property lower bound -> `p(reachable_dr)` until the current state
        - Property upper bound -> lower bound + imprecision
    - Temporal simulation -> bernoulli sampling
        - Results in a binomial distribution (with standard deviation)
- Test it on other larger networks

## NetDice-ish Dynamic Routing
### Structs
```
struct State:
    disabled -> list of network links that's going to be disabled in this state
    force_enable -> list of network links that's explicitly enabled and not marginalized 
    spur_node_idx -> how many first nodes does this state's shortest path shares with its parents?
end 

struct MetaPath:
    path -> list of nodes, representing a path
    dependencies -> list of State; what network state make this path the shortest one?
end
```

### Pseudocode
```
graph -> network graph
state_tree -> tree of State
A -> list of shortest MetaPath ordered by its path length
B -> priority queue of shortest path ordered by its path length

p_explored -> the percentage of state-space explored
p_property -> bounded reachability property

shortest_path = dijkstra(graph, src, dst)
s = State([], [], 1)
state_tree.insert(s)
A.push(MetaPath(shortest_path, [s]))

pf_path -> the probability of shortest_path being alive
p_explored += pf_path
p_property += pf_path

k = 1
while true
    mp = A[k]
    for d in mp.dependencies
        for spur_node_idx = d.spur_node_idx:length(mp.path) - 1
            # Fail links
            root_path = mp.path[1:spur_node_idx]
            spur_node = mp.path[spur_node_idx]
            failing_link = (spur_node, mp.path[spur_node_idx + 1])
            remove failing_link and the disabled list from d to its predecessor  

            # Calculate spur_path (if any)
            remove all links connected to nodes in root path
            spur_path = dijkstra(graph, spur_node, dst)
            restore all links connected to nodes in root path

            # Calculate the current state
            s = State([root_path], [failing_link], spur_path ? spur_node_idx : 1)
            state_tree.insert(s, parent=d)
            pf_dep -> the probability of s

            # Calculate total_path (if any)
            total_path = spur_path ? [root_path - 1; spur_path] : dijkstra(src, dst)
            if isempty(total_path)
                p_explored += pf_dep
                continue
            end

            # Calculate probability
            pf_path -> the probability of total_path being alive
            p_explored += pf_path * pf_dep
            p_property += pf_path * pf_dep

            if total_path is in B
                B[total_path].dependencies.push(s)
            else
                B.push(MetaPath(total_path, [s]))
            end

            restore graph
        end
    
    B empty? break
    A.push(B.pop())
    k += 1
end
```