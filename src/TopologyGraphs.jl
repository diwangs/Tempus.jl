module TopologyGraphs

using Graphs
using MetaGraphsNext

# TODO: EdgeData should contain the _failure rate_ (hardcoded for now)
const TopologyGraph = typeof(MetaGraph(Graph(), EdgeData= UInt64, weight_function= x -> x))
TopologyGraph() = MetaGraph(Graph(), EdgeData= UInt64, weight_function= x -> x)

end # module