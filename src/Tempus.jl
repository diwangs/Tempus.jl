module Tempus

import JSON
using DataStructures
using Random
using Distributions
import Distributions: cdf, pdf, logpdf, minimum, maximum, quantile, convolve

using Graphs
using MetaGraphsNext

using QuadGK # Numerical integration
using Roots

include("graphs/TopologyGraphs.jl")
include("graphs/LatencyGraphs.jl")

include("DirectDistributions.jl")
include("Direct.jl")

include("StateTrees.jl")
include("Exploration.jl")

# don't use 'using' or 'import' so that all globals are compartmentalized?

function main()
    json::String = open("artifacts/Highwinds.json") do file
        read(file, String)
    end
    config::Dict{String, Any} = JSON.parse(json)

    tg::TopologyGraph = TopologyGraph(config["routers"], config["links"])
    # lg::LatencyGraph = LatencyGraph(config["routers"], config["links"])
    # println(lg[:S1_S2, :S2])

    # a::Float64 = explore(tg, Symbol("3"), Symbol("10"))
    # println(a)
    # topgraph, delaygraph, fwdtable, intent = ConfigParser.parseconf("artifacts/Highwinds.json")
    # a = ModifiedYen.tempus_yen_stateful(topgraph, Symbol(intent["src"]), Symbol(intent["dst"]))
    # println(a)

    x = ecmpprob([[:S1, :S2, :S3, :S4], [:S1, :S2, :S5, :S4], [:S1, :S6, :S7, :S4]])
    println(x)
end

if !isinteractive()
    main()
end

end # module
