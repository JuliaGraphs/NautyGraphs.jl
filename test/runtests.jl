using NautyGraphs, Graphs
using NautyGraphs: Graphset, increase_padding!
using Test
using Random, LinearAlgebra
using Base.Threads

rng = Random.Xoshiro(0) 

@testset verbose=true "NautyGraphs" begin
    include("nautygraph.jl")
    include("graphset.jl")

    include("nauty.jl")
    include("interface.jl")
    VERSION == v"1.12" && include("aqua.jl")
    VERSION == v"1.12" && include("jet.jl")
end
