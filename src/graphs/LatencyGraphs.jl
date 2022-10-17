# EdgeData = Distribution
lgweightfunction = x -> x
const LatencyGraph = typeof(MetaGraph(DiGraph(), EdgeData = Distribution, weight_function = lgweightfunction))

function LatencyGraph(routers::Vector{Any}, links::Vector{Any})::LatencyGraph
    tg::LatencyGraph = MetaGraph(DiGraph(), EdgeData = Distribution, weight_function = lgweightfunction)

    # Make the nodes
    # TODO: src and dst
    for router::Dict{String, Any} in routers
        tg[Symbol(router["name"])] = nothing

        for port::Dict{String, Any} in router["outQdelayModel"]
            if port["to"] == "dst"
                continue
            end
            
            outQ::Symbol = Symbol(router["name"] * "_" * port["to"])
            tg[outQ] = nothing

            tg[Symbol(router["name"]), outQ] = gendist(port["delayModel"])
        end
    end

    # Make the links
    for link::Dict{String, Any} in links
        if link["u"] == "src" || link["v"] == "src" || link["u"] == "dst" || link["v"] == "dst"
            continue
        end

        tg[Symbol(link["u"] * "_" * link["v"]), Symbol(link["v"])] = gendist(link["delayModel"])
        tg[Symbol(link["v"] * "_" * link["u"]), Symbol(link["u"])] = gendist(link["delayModel"])
    end

    return tg
end

function gendist(delaymodel::Dict{String, Any})::Distribution
    # TODO: truncate to disallow negative delay
    args = Tuple(delaymodel["args"])
    return eval(Meta.parse(delaymodel["delayType"] * string(args)))
end