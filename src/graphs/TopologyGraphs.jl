# EdgeData = (failProb, weight)
tgweightfunction = x -> last(x)
const TopologyGraph = typeof(MetaGraph(DiGraph(), EdgeData = Tuple{Real, UInt}, weight_function = tgweightfunction))

function TopologyGraph(routers::Vector{Any}, links::Vector{Any})::TopologyGraph
    tg::TopologyGraph = MetaGraph(DiGraph(), EdgeData = Tuple{Real, UInt}, weight_function = tgweightfunction)

    # Make the nodes
    for router::Dict{String, Any} in routers
        tg[Symbol(router["name"])] = nothing
    end

    # Make the links
    for link::Dict{String, Any} in links
        if link["u"] == "src" || link["v"] == "src" || link["u"] == "dst" || link["v"] == "dst"
            continue
        end
        tg[Symbol(link["u"]), Symbol(link["v"])] = (link["failProb"], link["w_uv"])
        tg[Symbol(link["v"]), Symbol(link["u"])] = (link["failProb"], link["w_vu"])
    end

    return tg
end