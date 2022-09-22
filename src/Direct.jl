# KL-divergence integrand of one distribution with 2 different inputs
function kldivergence_integrand(d::Distribution, x1::Float64, x2::Float64)::Float64
    px = pdf(d, x1)
    log_px = logpdf(d, x1)
    log_qx = logpdf(d, x2)

    if log_px > -Inf && log_qx > -Inf
        return px * (log_px - log_qx)
    else
        return 0.0
    end
end

# Symmetric KL-divergence between one distribution with a shifted input
function sym_kldivergence_shift(d::Distribution, shift::Float64)::Float64
    # forward KL-divergence
    forward = first(quadgk(x -> kldivergence_integrand(d, x, x-shift), extrema(d)...))
    # backward KL-divergence
    backward = first(quadgk(x -> kldivergence_integrand(d, x-shift, x), extrema(d)...))

    return forward + backward
end

function direct(d1::UnivariateDistribution, d2::UnivariateDistribution, delta::Float64 = 0.01, epsilon::Float64 = 0.0001)
    # Determine bin half-width from delta
    step = sqrt(delta)
    while sym_kldivergence_shift(d2, step) < delta
        step = step * 2
    end
    step = find_zero(x -> sym_kldivergence_shift(d2, x) - delta, (0, step))

    # Determine grid range from epsilon
    mini = -1.0
    maxi = 1.0
    while cdf(d1, mini) > epsilon / 2
        mini = mini * 2
    end
    while cdf(d1, maxi) < 1 - (epsilon / 2)
        maxi = maxi * 2
    end
    mini = find_zero(x -> cdf(d1, x) - (epsilon / 2), (mini, maxi))
    maxi = find_zero(x -> cdf(d1, x) - (1 - epsilon / 2), (mini, maxi))

    # Determine reference points
    k = ceil(Int, (maxi - mini)/(2 * step)) + 1
    supports = [mini - ((2 * k * step) - (maxi - mini)) / 2 + 2 * x * step for x in 0:(k-1)]
    
    # Determine bin weights
    margins = supports[2:length(supports)] .- step
    weights = [cdf(d1, margins[i]) for i in 1:(k-1)]
    weights = [weights; 1.0]
    for i in k:-1:2
        weights[i] = weights[i] - weights[i - 1]
    end

    return DirectDistribution{Float64}(supports, weights, d2, delta, epsilon)
end

convolve(d1::ContinuousUnivariateDistribution, d2:: ContinuousUnivariateDistribution) = direct(d1, d2)