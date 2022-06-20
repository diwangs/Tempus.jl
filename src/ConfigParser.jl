module ConfigParser

using JSON
using Graphs
using MetaGraphsNext
using Distributions

function parseconf(path::String) # Outputs a metagraph
    # x::String = open(path) do file
    #     read(file, String)
    # end

    function f(data::Dict{String, Any})
        # TODO: negative number?
        if data["dist"] == "normal"
            return rand(Normal(data["mean"], data["stdev"]))
        elseif data["dist"] == "uniform"
            return rand(Uniform(data["min"], data["max"]))
        elseif data["dist"] == "const"
            return data["val"]
        end
    end

    g = MetaGraph( Graph(), EdgeData = Dict{String, Any}, weight_function = f)
    # Empty weight = 1?

    # Create node
    g[:a] = nothing 
    g[:b] = nothing 
    g[:c] = nothing
    g[:d] = nothing
    # g[:e] = nothing
    # g[:f] = nothing
    # g[:g] = nothing


    # Create edges
    g[:a, :b] = Dict("dist" => "const", "val" => 1.0, "prob" => 0.9)
    g[:a, :c] = Dict("dist" => "const", "val" => 1.0, "prob" => 0.9)
    g[:b, :d] = Dict("dist" => "const", "val" => 1.0, "prob" => 0.9)
    # g[:b, :e] = Dict("dist" => "const", "val" => 1.0, "prob" => 0.9)
    # g[:c, :f] = Dict("dist" => "const", "val" => 1.0, "prob" => 0.9)
    # g[:d, :g] = Dict("dist" => "const", "val" => 1.0, "prob" => 0.9)
    # g[:e, :g] = Dict("dist" => "const", "val" => 1.0, "prob" => 0.9)
    # g[:f, :g] = Dict("dist" => "const", "val" => 1.0, "prob" => 0.9)
    g[:c, :d] = Dict("dist" => "const", "val" => 1.0, "prob" => 0.9)


    # Double weighted undirected graph -> Edge-weighted directed graph
    # Weight -> a function of time and edge data
    return g

    # println(rand(JSON.parse(x)["routers"][1]["delayMin"]:JSON.parse(x)["routers"][1]["delayMax"]))

    # Run simulation
    # d = Distributions.Normal(5, 1)
    # threshold::Int64 = 8
    # Early stop if the running time is more than the threshold

end

end