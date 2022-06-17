module Tempus

include("ConfigParser.jl")
include("ProbTraversal.jl")

# don't use 'using' or 'import' so that all globals are compartmentalized?

greet() = print("Hello World!")

function main()
    g = ConfigParser.parseconf("test.json")
    ProbTraversal.traverse(g, [[:a, :b, :d, :g], [:a, :b, :e, :g], [:a, :c, :f, :g]])
end

# Traversal algorithm
# - Compute probability
# - If one of them is fail, count as failure
# - If successful, sum all the time
# - 

# Keep count of the number of success / total run (more or less than the threshold)
    
# success::Int64 = 90
# runs::Int64 = 100
# println(StatsBase.confint(HypothesisTests.BinomialTest(success, runs), level=0.95)) # ignore p in BinomialTest

end # module
