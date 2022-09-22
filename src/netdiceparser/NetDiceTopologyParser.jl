module TopologyParser

import JSON

function main()
    tempusConfig = Dict()

    open("artifacts/Highwinds.in") do f 
        
        s = readline(f) # Read the first line containing the number of nodes
        routers = [Dict(
            "name" => string(i - 1), 
            "failProb" => 0.0,
            "delayModel" => Dict(
                "delayType" => "Normal",
                "args" => [1, 0]
            )
        ) for i in 1:parse(Int64, s)]

        tempusConfig["routers"] = routers

        links = []
        while !eof(f)
            line = readline(f)
            array = split(line, " ")
            push!(links, Dict(
                "u" => array[1], 
                "v" => array[2],
                "failProb" => 0.1,
                "delayModel" => Dict(
                    "delayType" => "Normal",
                    "args" => [1, 0]
                )
            ))
        end

        tempusConfig["links"] = links

        println(JSON.json(tempusConfig))
        # println(s)
    end

    open("artifacts/Highwinds.json", "w") do f
        write(f, JSON.json(tempusConfig))
    end
end

if !isinteractive()
    main()
end

end # module