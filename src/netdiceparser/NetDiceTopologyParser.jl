module TopologyParser

import JSON
using Random

function main()
    tempusConfig = Dict()

    open("artifacts/" * ARGS[1]) do f 
        
        r = readline(f) # Read the first line containing the number of nodes
        
        # outQ = Dict{String, Vector{String}}()

        links = []
        while !eof(f)
            line = readline(f)
            array = split(line, " ")
            push!(links, Dict(
                "u" => array[1], 
                "v" => array[2],
                "w_uv" => parse(Int, array[3]),
                "w_vu" => parse(Int, array[4]),
                "failProb" => 0.001,
                "delayModel" => rand(Bool) ? Dict(
                    "isEmpiric" => true,
                    "delayType" => "Gamma",
                    "args" => []
                ) : Dict(
                    "isEmpiric" => true,
                    "delayType" => "Chisq",
                    "args" => [3]
                )
            ))
        end

        routers = []
        for i in 1:parse(Int64, r)
            name::String = string(i - 1)
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
            "src" => ARGS[3],
            "dst" => ARGS[4],
            "threshold" => 1000.0
        )

        println(JSON.json(tempusConfig))
        # println(s)
    end

    open("artifacts/" * ARGS[2], "w") do f
        write(f, JSON.json(tempusConfig))
    end
end

if !isinteractive()
    main()
end

end # module