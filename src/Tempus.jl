module Tempus

include("ConfigParser.jl")
include("ProbTraversal.jl")

# don't use 'using' or 'import' so that all globals are compartmentalized?

function main()
    # 3-tuple (G, routing_info, timing_info)
    # routing_info and timing_info is used for calculating weight (with different weight function)
    # routing_info -> for now it's manually supplied by fwdTable
    # timing_info -> delayModel

    g, fwdtable, intent = ConfigParser.parseConf("artifacts/ecmp2.json")
    prob::Float64 = ProbTraversal.traversestatic(g, fwdtable, intent)
    println("Probability: $(prob)")
    # ProbTraversal.traverse_dynamic(g, [[:b, :c], [:d], [:d], []])
end

if !isinteractive()
    main()
end

end # module
