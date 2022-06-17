# tempus.jl
Time-conscious Network Verifier

## Encoding
- Double-weighted graph -> edge-weighted directed graph
- Random weights via MetaGraph weight function
- Time-dependent graph with their TD graph algorithm?

## Traversal
- Look for probability through monte-carlo simulation
    - https://docs.uppaal.org/language-reference/requirements-specification/ci_estimation/
- TDSP
- Specific to threshold: success probability

# Property Verification
- Bounded reachability: the probability that host A transporting packet to host B in under T time unit, given:
    - Topology and random failure of components
    - Forwarding table

## Fixed Reachability Model
- Assume a fixed forwarding table
- For a given _forwarding table_ and _source-destination pair_, we can enumerate legible _paths_ (based on ECMP)
- __Single-Path Bounded Reachability__: reachable (R) iff the components in the path are up (U) AND the path's theoretical propagation delay is below T (D)
    - P(R) = P(U, D)
    - "Theoretical" -> based on the model, assuming that the relevant components are up
    - Independent: P(U, D) = P(U) P(D)
    - P(U): computed analytically -> product of the success rate of the components
    - P(D): computed numerically -> simulate the path propagation (each components might have a certain distribution / change with time)
- __Multi-Path Bounded Reachability__: reachable (R) iff one of the path is reachable (R1, R2, ...)
    - Example for 2 paths: P(R) = P(R1 OR R2) = P(R1) + P(R2) - P(R1, R2)
    - Not independent: P(R1, R2) != P(R1) P(R2), might share components
    - R1 AND R2: reachable from both path1 and path2 iff the components in both paths are up (U12) AND both path's theoretical propagation delay is below T (D12)
    - P(U12): product of the success rate of the components, joint components only counted once
    - P(D12): the minimum of P(D1) and P(D2)? -> subject to further discussion
    - Generalizes to more than two paths

## Transient state
- Forwarding table also changes over time -> routing protocols
    - Pre-convergent 
        - No change in topology
        - Run the fixed reachability model with different forwarding table 
    - Component failure -> dynamic topology, dynamic forwarding table
        - Component failure can trigger change in forwarding table
- Simulation
    - Bring the components failure model to the simulation -> more similar to the UPPAAL model
    - Have packets traverse the path, count the success 
        - Can add a routine to handle forwarding graph change
    - Consequence -> different result from NetDice, even for convergent state and setting aside time bound
        - Diamond -> 0.9639 vs 0.891
        - Double counting the states
- Consequence for the bounded reachability property
    - If we want to reduce the result of the simulation to a probability number, it would vary based on the range of time of the queueing delay?