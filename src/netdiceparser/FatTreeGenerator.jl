module FatTreeGenerator

using Printf
using JSON

function main() 
    k = parse(Int, ARGS[1]) # number of pods

    tempusConfig = Dict()

    # Link 
    links = []
    for pod in 1:k
        for idx in 1:(k/2) # For every aggregation switch...
            for dst in 1:(k/2)
                # Connect to edge switch in the same pods in a bipartite manner
                push!(links, Dict(
                    "u" => @sprintf("aggr_%d_%d", pod, idx),
                    "v" => @sprintf("edge_%d_%d", pod, dst),
                    "w_uv" => 1,
                    "w_vu" => 1,
                    "failProb" => 0.001,
                    "delayModel" => Dict(
                        "isEmpiric" => true,
                        "delayType" => "Gamma",
                        "args" => []
                    )
                ))

                # Aggr is connected to k/2 core
                push!(links, Dict(
                    "u" => @sprintf("aggr_%d_%d", pod, idx), 
                    "v" => @sprintf("core_%d", (idx - 1) * (k/2) + dst),
                    "w_uv" => 1,
                    "w_vu" => 1,
                    "failProb" => 0.001,
                    "delayModel" => Dict(
                        "isEmpiric" => true,
                        "delayType" => "Gamma",
                        "args" => []
                    )
                ))
            end
        end
    end

    # Routers
    # k pods
    #   k/2 edge routers -> edge_1_1: edge, pod 1, index 1
    #   k/2 aggr routers -> aggr_1_2: aggr, pod 1, index 2
    # (k/2)^2 core routers -> core_1, core_2, ...
    routers = []
    for pod in 1:k
        for idx in 1:(k/2)
            name = @sprintf("edge_%d_%d", pod, idx)
            push!(routers, Dict(
                "name" => name,
                "failProb" => 0.0,
                "outQdelayModel" => [Dict(
                    "to" => link["u"] == name ? link["v"] : link["u"],
                    "delayModel" => Dict(
                        "isEmpiric" => true,
                        "delayType" => "Empiric",
                        "args" => ["queue_measurement/dctcp_us.csv"]
                    )
                ) for link in filter(x -> x["u"] == name || x["v"] == name, links)]
            ))

            name = @sprintf("aggr_%d_%d", pod, idx)
            push!(routers, Dict(
                "name" => name,
                "failProb" => 0.0,
                "outQdelayModel" => [Dict(
                    "to" => link["u"] == name ? link["v"] : link["u"],
                    "delayModel" => Dict(
                        "isEmpiric" => true,
                        "delayType" => "Empiric",
                        "args" => ["queue_measurement/dctcp_us.csv"]
                    )
                ) for link in filter(x -> x["u"] == name || x["v"] == name, links)]
            ))
        end
    end
    for idx in 1:(k/2)^2
        name = @sprintf("core_%d", idx)
        push!(routers, Dict(
            "name" => name,
            "failProb" => 0.0,
            "outQdelayModel" => [Dict(
                "to" => link["u"] == name ? link["v"] : link["u"],
                "delayModel" => Dict(
                    "isEmpiric" => true,
                    "delayType" => "Empiric",
                    "args" => ["queue_measurement/dctcp_us.csv"]
                )
            ) for link in filter(x -> x["u"] == name || x["v"] == name, links)]
        ))
    end

    tempusConfig["routers"] = routers
    tempusConfig["links"] = links
    tempusConfig["intent"] = Dict(
        "src" => "edge_1_1",
        "dst" => @sprintf("edge_%d_%d", k, k/2),
        "threshold" => 1000.0
    )

    println(JSON.json(tempusConfig))
end

if !isinteractive()
    main()
end

end # module