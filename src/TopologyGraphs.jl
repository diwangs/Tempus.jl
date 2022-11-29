# EdgeData = (failprob, latencydist, ospfweight)
tgweightfunction = x -> last(x)
const TopologyGraph = typeof(MetaGraph(DiGraph(), EdgeData = Tuple{Real, Distribution, Distribution, UInt}, weight_function = tgweightfunction))

function TopologyGraph(routers::Vector{Any}, links::Vector{Any})::TopologyGraph
    tg::TopologyGraph = MetaGraph(DiGraph(), EdgeData = Tuple{Real, Distribution, Distribution, UInt}, weight_function = tgweightfunction)

    # Make the nodes
    for router::Dict{String, Any} in routers
        tg[Symbol(router["name"])] = nothing
    end

    # Make the links
    for link::Dict{String, Any} in links
        # TODO: include src and dst link
        if link["u"] == "src" || link["v"] == "src" || link["u"] == "dst" || link["v"] == "dst"
            continue
        end

        # println(link)
        linkdist = gendist(link["delayModel"])
        uvdist = gendist(getdelaymodel(routers, link["u"], link["v"]))
        tg[Symbol(link["u"]), Symbol(link["v"])] = (link["failProb"], linkdist, uvdist, link["w_uv"])
        vudist = gendist(getdelaymodel(routers, link["v"], link["u"]))
        tg[Symbol(link["v"]), Symbol(link["u"])] = (link["failProb"], linkdist, vudist, link["w_vu"])
        # Link failure should nullify both connections
    end

    return tg
end

function getdelaymodel(routers::Vector{Any}, u, v::String)::Dict{String, Any}
    routeroutQ = filter(x -> x["name"] == u, routers)[1]["outQdelayModel"]
    return filter(x -> x["to"] == v, routeroutQ)[1]["delayModel"]
end

function gendist(delaymodel::Dict{String, Any})::Distribution
    args = Tuple(delaymodel["args"])
    rawdist = eval(Meta.parse(delaymodel["delayType"] * string(args)))
    # Truncate to disallow negative delay
    if cdf(rawdist, 0.0) <= 0.0 # TODO: change this threshold
        return rawdist 
    else
        return truncated(rawdist; lower=0.0)
    end
end