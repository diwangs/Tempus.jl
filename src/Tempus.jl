module Tempus

import JSON
using Distributions
import Distributions: cdf, pdf, logpdf, minimum, maximum, quantile, convolve

using Graphs
using MetaGraphsNext

using QuadGK # Numerical integration
using Roots

include("graphs/TopologyGraphs.jl")

include("DirectDistributions.jl")
include("Direct.jl")

# don't use 'using' or 'import' so that all globals are compartmentalized?

function main()
    json::String = open("artifacts/7nodenew.json") do file
        read(file, String)
    end
    config::Dict{String, Any} = JSON.parse(json)

    tg::TopologyGraph = TopologyGraph(config["routers"], config["links"])
    println(tg)
    # topgraph, delaygraph, fwdtable, intent = ConfigParser.parseconf("artifacts/Highwinds.json")
    # a = ModifiedYen.tempus_yen_stateful(topgraph, Symbol(intent["src"]), Symbol(intent["dst"]))
    # println(a)

    # x = Normal(1, 1)
    # y = convolve(x, x)
    # z = convolve(y, y)
    # println(cdf(z, 4.0))
end

if !isinteractive()
    main()
end

end # module
