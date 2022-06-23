module ConfigParser

import JSON
using Graphs
using MetaGraphsNext
using Distributions

function parseConf(path::String) # Outputs a metagraph
    json::String = open(path) do file
        read(file, String)
    end

    config::Dict{String, Any} = JSON.parse(json)

    # Construct a directed edge-weighted graph that is equivalent to a doubly-weighted graph
    g = MetaGraph( DiGraph(), VertexData = Bool, EdgeData = Dict{String, Any}, weight_function = f)
    # VertexData = is_output

    # Create routers
    for router::Dict{String, Any} in config["routers"]
        g[Symbol(router["name"] * "_in")] = false
        g[Symbol(router["name"] * "_out")] = true
        g[Symbol(router["name"] * "_in"), Symbol(router["name"] * "_out")] = filter(p -> p.first != "name", router)
    end

    # Create links
    for link::Dict{String, Any} in config["links"]
        g[Symbol(link["u"] * "_out"), Symbol(link["v"] * "_in")] = filter(p -> p.first != "u" && p.first != "v" , link)
        g[Symbol(link["v"] * "_out"), Symbol(link["u"] * "_in")] = filter(p -> p.first != "u" && p.first != "v" , link)
    end
    # Empty weight = 1?

    return g, config["fwdTable"], config["intent"]
    # Right now intent also returns the forwarding table, but it will be computed by OSPF later
end

function f(data::Dict{String, Any})
    # TODO: negative number?
    if data["delayModel"]["delayType"] == "normal"
        return rand(Normal(data["delayModel"]["mean"], data["delayModel"]["stdev"]))
    elseif data["delayModel"]["delayType"] == "uniform"
        return rand(Uniform(data["delayModel"]["min"], data["delayModel"]["max"]))
    elseif data["delayModel"]["delayType"] == "const"
        return data["delayModel"]["value"]
    end
end

end