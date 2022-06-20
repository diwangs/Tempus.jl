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
    - P(U): computed analytically
        - Sample space: the status of all components in the path (e.g. {up, up, down}, etc.)
        - Probability function: product of the success rate of the components (0.9 * 0.9 * 0.1)
    - P(D): computed numerically -> use the sample distribution (simulation) to estimate population
        - Simulate the packet propagation
            - Iterate through each components, sample its delay, add them
            - Each components have a certain distribution / change with time
            - Either save the total in a buffer (make it available for plotting) or do early stopping 
        - Sample space: yes or no 
            - But not a bernoulli process, since dynamic queuing delay makes it not IID?
        - Probability function = run below T / total run
- __Multi-Path Bounded Reachability__: reachable (R) iff one of the path is reachable (R1, R2, ...)
    - Example for 2 paths: P(R) = P(R1 OR R2) = P(R1) + P(R2) - P(R1, R2)
    - Not independent: P(R1, R2) != P(R1) P(R2), might share components
    - R1 AND R2: reachable from both path1 and path2 iff the components in both paths are up (U12) AND both path's theoretical propagation delay is below T (D12)
    - P(U12): same as above, but joint components only counted once
    - P(D12): the minimum of P(D1) and P(D2)? -> subject to further discussion
    - Generalizes to more than two paths (with changes to the additive rule)
- NetDice basically does the same thing, but not with additive rule

## Dynamic Reachability Model
- A change in topology (due to failure) might change the forwarding table
- Integrate P(U) calculation in the packet propagation simulation
- Steps
    - Initialize forwarding graph, source, and destination host
    - Iterate through each component 
        - Get a current component (initialize as the source host)
            - If the current component is the destination host, count this run as a success, log the propagation delay
        - Sample a random number for the failure rate
            - If success, continue
            - If fail, count this run as fail, trigger some logic to change the forwarding graph
        - Sample its delay, add them to the current run's propagation delay
        - Get the next components based on the forwarding graph (random in case of ECMP)
    - Save the (successful) total propagation delay _and_ the status (success / fail) of the run 
- Similar decomposition of reachability, but P(U) is different
    - P(U): success run / total run
    - P(D): success run below T / success run
- No need to consider separate single-path / multi-path scenario

# Difference
- Ignoring routing protocols and P(D) for a moment (by setting it to a very high value), how we calculate P(U) is different
- Diamond network gets different results:
    - Fixed, NetDice: 0.9639 = 2 * 0.9^2 - 0.9^4
    - Dynamic: 0.81 = 0.9 * 0.9
- From the perspective of the fixed reachability model, the dynamic model _double counts_ state 
    - You could think of 0.9 * 0.9 is a marginalisation of 
        - 0.9 * 0.9 * 0.9 * 0.9, 
        - 0.9 * 0.9 * 0.9 * 0.1, 
        - etc.
    - The 0.9^4 state is being double counted
- Different sample space?
    - Fixed: status of _all path's_ components
    - Dynamic: status of _current path's_ components

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