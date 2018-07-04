struct NonSequentialNetworkFlow <: SimulationSpec{NonSequential}
    nsamples::Int

    function NonSequentialNetworkFlow(nsamples::Int)
        @assert nsamples > 0
        new(nsamples)
    end
end

function all_load_served(A::Matrix{T}, B::Matrix{T}, sink::Int, n::Int) where T
    served = true
    i = 1
    while served && (i <= n)
        served = A[i, sink] == B[i, sink]
        i += 1
    end
    return served
end

function assess(simulationspec::NonSequentialNetworkFlow,
                resultspec::MinimalResult,
                system::SystemDistribution{N,T,P,Float64}) where {N,T,P}

    systemsampler = SystemSampler(system)
    sink_idx = nv(systemsampler.graph)
    source_idx = sink_idx-1
    n = sink_idx-2

    state_matrix = zeros(sink_idx, sink_idx)
    lol_count = 0
    lol_sum = 0.
    # failure_states = FailureResult{Float64}[]

    flow_matrix = Array{Float64}(sink_idx, sink_idx)
    height = Array{Int}(sink_idx)
    count = Array{Int}(2*sink_idx+1)
    excess = Array{Float64}(sink_idx)
    active = Array{Bool}(sink_idx)

    for i in 1:simulationspec.nsamples

        rand!(state_matrix, systemsampler)
        systemload, flow_matrix =
            LightGraphs.push_relabel!(flow_matrix, height, count, excess, active,
                          systemsampler.graph, source_idx, sink_idx, state_matrix)

        if !all_load_served(state_matrix, flow_matrix, sink_idx, n)

            # TODO: Save whether generator or transmission constraints are to blame?
            lol_count += 1
            #lol_sum += 0

            # simulationspec.persist && push!(failure_states, FailureResult(state_matrix, flow_matrix, system.interface_labels, n))

        end

    end

    μ = lol_count/simulationspec.nsamples
    σ² = μ * (1-μ)
    # eue_val, E = to_energy(lol_sum/simulationspec.nsamples, P, N, T)
    eue_val, E = to_energy(Inf, P, N, T)

    # detailed_results = FailureResultSet(failure_states, system.interface_labels)

    return SinglePeriodMinimalResult{P}(
        LOLP{N,T}(μ, sqrt(σ²/simulationspec.nsamples)),
        EUE{E,N,T}(eue_val, 0.),
        simulationspec
    )

end
