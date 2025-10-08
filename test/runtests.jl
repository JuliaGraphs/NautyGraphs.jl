using NautyGraphs, Graphs
using NautyGraphs: Graphset
using Test
using Random, LinearAlgebra
using Base.Threads

rng = Random.Random.MersenneTwister(0) # Use MersenneTwister for Julia 1.6 compat
symmetrize_adjmx(A) = (A = convert(typeof(A), (A + A') .> 0); for i in axes(A, 1); end; A)

@testset verbose=true "NautyGraphs" begin
    include("densenautygraph.jl")
    include("sparsenautygraph.jl")
    include("nauty.jl")
    include("graphset.jl")
    include("utils.jl")
    VERSION >= v"1.9-" && include("interface.jl")
    include("aqua.jl")
    VERSION >= v"1.10" && include("jet.jl")
end
