module Tempus

using Pkg
Pkg.instantiate()
Pkg.add("CSV")
Pkg.add("EmpiricalDistributions")

using Logging
import JSON
import CSV
using DataStructures
using Random
using Dates

using Distributions
import Distributions: cdf, pdf, logpdf, minimum, maximum, quantile, convolve
using StatsBase
using EmpiricalDistributions
import EmpiricalDistributions: _linear_interpol, _ratio

using Graphs
import Graphs: weights
using MetaGraphsNext

using QuadGK # Numerical integration
using Roots

include("Direct.jl")
include("TopologyGraphs.jl")
include("StateTrees.jl")
include("Exploration.jl")

function _linear_interpol(x_lo::Real, x_hi::Real, y_lo::Real, y_hi::Real, x::Real)
    T = promote_type(typeof(y_lo), typeof(y_hi), typeof(x))
    w_hi = T(_ratio(x - x_lo, x_hi - x_lo))
    w_lo = one(w_hi) - w_hi
    y = y_lo * w_lo + y_hi * w_hi
    # Original assertion might fail in the case of float rounding error
    # @assert y_lo <= y <= y_hi 
    !(y_lo < y) && @assert isapprox(y_lo, y)
    !(y < y_hi) && @assert isapprox(y, y_hi)
    y
end

function main()
    size(ARGS)[1] < 1 && (println("Please provide a file name as an input (and optionally optimization level)"); return 1)

    json::String = open("artifacts/" * ARGS[1]) do file
        read(file, String)
    end
    config::Dict{String, Any} = JSON.parse(json)
    if size(ARGS)[1] == 1
        opt = "opti"
    else
        opt = ARGS[2]
    end

    tg::TopologyGraph = TopologyGraph(config["routers"], config["links"])
    # @info ne(tg) / 2

    prob::Float64 = explore(tg, Symbol(config["intent"]["src"]), Symbol(config["intent"]["dst"]), config["intent"]["threshold"], opt)
    @info prob
end

if !isinteractive()
    main()
end

end # module