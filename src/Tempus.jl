module Tempus

import JSON
using DataStructures
using Random
using Distributions
import Distributions: cdf, pdf, logpdf, minimum, maximum, quantile, convolve
using Dates

using Graphs
using MetaGraphsNext

using QuadGK # Numerical integration
using Roots

include("Direct.jl")
include("TopologyGraphs.jl")
include("StateTrees.jl")
include("Exploration.jl")

function main()
    isempty(ARGS) && (println("Please provide a file name as an input"); return 1)

    json::String = open("artifacts/" * ARGS[1]) do file
        read(file, String)
    end
    config::Dict{String, Any} = JSON.parse(json)

    tg::TopologyGraph = TopologyGraph(config["routers"], config["links"])
    prob::Float64 = explore(tg, Symbol(config["intent"]["src"]), Symbol(config["intent"]["dst"]), config["intent"]["threshold"])
    println(prob)

    # start = now()
    # x = LogNormal()
    # y = Exponential()
    # # z = convolve(convolve(x, x), y)
    # z = convolve(x, x)
    # println(now() - start)
    # println(z)
end

if !isinteractive()
    main()
end

end # module