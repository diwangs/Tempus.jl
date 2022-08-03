module ConfigParser

import JSON
using Graphs
using MetaGraphsNext
using Distributions
using Random

include("TopologyGraphs.jl")

function parseconf(path::String) # Outputs a metagraph
    json::String = open(path) do file
        read(file, String)
    end

    config::Dict{String, Any} = JSON.parse(json)

    # topology_graph = MetaGraph(Graph(), EdgeData = Dict{String, Any}, weight_function=sample_delay)
    tg = TopologyGraphs.TopologyGraph()
    # Delay graph: Construct a directed edge-weighted graph that is equivalent to a doubly-weighted graph
    delay_graph = MetaGraph(DiGraph(), VertexData = Bool, EdgeData = Dict{String, Any}, weight_function = sample_delay)
    # VertexData = is_output

    # Create routers
    for router::Dict{String, Any} in config["routers"]
        # topology_graph[Symbol(router["name"])] = nothing
        tg[Symbol(router["name"])] = nothing

        delay_graph[Symbol(router["name"] * "_in")] = false
        delay_graph[Symbol(router["name"] * "_out")] = true
        delay_graph[Symbol(router["name"] * "_in"), Symbol(router["name"] * "_out")] = filter(p -> p.first != "name", router)
    end

    # Create links
    for link::Dict{String, Any} in config["links"]
        # topology_graph[Symbol(link["u"]), Symbol(link["v"])] = filter(p -> p.first != "u" && p.first != "v" , link)
        tg[Symbol(link["u"]), Symbol(link["v"])] = 1.0
        # tg[Symbol(link["v"]), Symbol(link["u"])] = 1.0

        delay_graph[Symbol(link["u"] * "_out"), Symbol(link["v"] * "_in")] = filter(p -> p.first != "u" && p.first != "v" , link)
        delay_graph[Symbol(link["v"] * "_out"), Symbol(link["u"] * "_in")] = filter(p -> p.first != "u" && p.first != "v" , link)
    end
    # Empty weight = 1?

    # println(ne(topology_graph))
    return tg, delay_graph, config["fwdTable"], config["intent"]
    # Right now intent also returns the forwarding table, but it will be computed by OSPF later
end

function sample_delay(data::Dict{String, Any})
    d::Distribution = gen_dist(data["delayModel"])
    return rand(d)
end

function gen_dist(delaymodel::Dict{String, Any})::Distribution
    # TODO: truncate to disallow negative delay
    args = Tuple(delaymodel["args"])
    return eval(Meta.parse(delaymodel["delayType"] * string(args)))
end

end # module