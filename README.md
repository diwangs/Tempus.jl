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
- Bounded reachability: the probability that node A transporting packet to node B in under T time unit, given:
    - Failure rate of components
    - Topology
    - Forwarding table
- __Paths__ will be the primary unit of reasoning to determine the propagation delay of a packet
    - Delay of a given packet depends on the path it traverse
        - Since delay is causal (total delay of a packet at a given point in time depends on the previous component they traverse)
    - The path it traverse depends on the forwarding graph
        - For a given _forwarding table_ and _source-destination pair_, we can enumerate legible _paths_
        - Can take multiple equally-probable path (e.g. ECMP)
    - Forwarding graph depends on the routing protocol
- NetDice: topology variation -> routing protocol -> converged forwarding graph -> property fulfillment, probability calculation
- Current: forwarding graph -> path -> topology variation -> property fulfillment, probability calculation

## Single-Path
- __Assumption__: 
    - A network where the given source-destination pair only has one path
    - e.g. path graph network, static routing
- __Reachability Definition__: Reachable (R) iff the components in the path are up (U) AND the path's theoretical propagation delay is below T (D)
- P(R) = P(U, D)
- "Theoretical" -> based on the model, assuming that the relevant components are up
- Independent: P(U, D) = P(U) P(D)
- P(U): computed analytically
    - Sample space: the status of all components in the path (e.g. {up, up, down}, etc.)
    - Probability function: product of the probability of the components being in that state (0.9 * 0.9 * 0.1)
- P(D): computed numerically -> use the sample distribution (simulation) to estimate population
    - Simulate the packet propagation
        - Iterate through each components, sample its delay, add them
        - Each components have a certain distribution / change with time
        - Either save the total in a buffer (make it available for plotting) or do early stopping 
    - In contrast to convolution: simulation can support richer delay model
        - Convolution needs to have similar probability distribution
    - Sample space: yes or no 
        - But not a bernoulli process, since dynamic queuing delay makes it not IID?
    - Probability function = run below T / total run

## Reducible Multi-Path
- __Assumption__:
    - A network where the given source-destination pair has multiple paths, represented by a path list
    - The path list is _reducible_ -> given arbitrary combination of component failure, the network won't add _new_ paths to the list
    - e.g. ECMP
- __Reachability Definition__: Reachable (R) iff one of the path is reachable (R1, R2, ...)
- Example for 2 paths: P(R) = P(R1 OR R2) = P(R1) + P(R2) - P(R1, R2)
- Not independent: P(R1, R2) != P(R1) P(R2), might share components
- R1 AND R2: reachable from both path1 and path2 iff the components in both paths are up (U12) AND both path's theoretical propagation delay is below T (D12)
- P(U12): same as single-path, but joint components only counted once
- P(D12): the minimum of P(D1) and P(D2)? -> subject to further discussion
- Generalizes to more than two paths (with changes to the additive rule)
- __Approximating Dynamic Routing__:
    - A network topology that supports path redundancy might add a new (often slightly longer) path to the list if some combination of components fail
        - e.g. dynamic routing
        - Makes the path list irreducible
    - Stopgap solution -> enumerate all paths to make the path list reducible
        - Enumerate all paths _accross changes in forwarding table_
        - Problem: enumerating all paths in an arbitrary graph is NP-hard (see longest path problem)
        - Reasonable replacement -> Yen's Algorithm (loopless k-shortest path problem)

## Dynamic Routing (post-convergence)
- Given a topology, component failure rate, and a routing protocol:
    - Enumerate over `new_topology, p_state = f(topology, comp_failure_rate)`
        - Use cold-edges technique to do it smarter, requires routing protocol
    - Path-based: 
        - Compute `paths = routing_protocol(new_topology, src, dst)` -> collect reducible paths
            - Ignoring `p_state`
        - Wait until reducible paths has been collected
            - We're using Yen's algorithm to collect all paths (merge with the previous steps)
        - Compute the probability for a certain combination of paths in the list (previous section)
            - Ignoring components that are not in the paths
        - Combine using additive rule
    - Topology-based (NetDice):
        - Compute `paths = routing_protocol(new_topology, src, dst)`
        - Compute `P(D)` using that `paths`
        - Add the `p_state * P(D)` to the overall p_property
- Comparison
    - Path-based -> scales to the number of paths 
        - In a real network, almost always worse than the number of the components?
            - Highwinds -> 18 nodes, 52 links, 407 paths between 2 edges
        - Better for small paths -> path network
        - Can use n (kCn) to early stop?
    - Topology-based -> scales to the number of components
        - Better for real networks?
        - Can use `p_state` to early stop at a given precision