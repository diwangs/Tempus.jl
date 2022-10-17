module TopologyParser

import JSON

function main()
    tempusConfig = Dict()

    open("artifacts/AttMpls.in") do f 
        
        r = readline(f) # Read the first line containing the number of nodes
        
        # outQ = Dict{String, Vector{String}}()

        links = []
        while !eof(f)
            line = readline(f)
            array = split(line, " ")
            push!(links, Dict(
                "u" => array[1], 
                "v" => array[2],
                "w_uv" => 1,
                "w_vu" => 1,
                "failProb" => 0.1,
                "delayModel" => Dict(
                    "delayType" => "Normal",
                    "args" => [1, 0]
                )
            ))

            # outQ[array[1]] = 
            # outQ[array[2]] = 
        end

        routers = [Dict(
            "name" => string(i - 1), 
            "failProb" => 0.0,
            "delayModel" => Dict(
                "delayType" => "Normal",
                "args" => [1, 0]
            )
        ) for i in 1:parse(Int64, r)]

        tempusConfig["routers"] = routers
        tempusConfig["links"] = links

        println(JSON.json(tempusConfig))
        # println(s)
    end

    open("artifacts/AttMpls.json", "w") do f
        write(f, JSON.json(tempusConfig))
    end
end

if !isinteractive()
    main()
end

end # module