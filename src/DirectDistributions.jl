struct DirectDistribution{T<:Real} <: ContinuousUnivariateDistribution
    supports::Vector{T}
    weights::Vector{T}
    d2::Distribution

    delta::T
    epsilon::T
end

cdf(d::DirectDistribution, x::Real) = sum(d.weights .* [cdf(d.d2, x - support) for support in d.supports])
pdf(d::DirectDistribution, x::Real) = sum(d.weights .* [pdf(d.d2, x - support) for support in d.supports])
logpdf(d::DirectDistribution, x::Real) = log(pdf(d, x))
maximum(d::DirectDistribution) = Inf
minimum(d::DirectDistribution) = -Inf

function quantile(d::DirectDistribution, q::Real)
    mini = -1.0
    maxi = 1.0
    while cdf(d, mini) > q
        mini = mini * 2
    end
    while cdf(d, maxi) < q
        maxi = maxi * 2
    end
    return find_zero(x -> cdf(d, x) - q, (mini, maxi))
end