using NautyGraphs, Graphs
using NautyGraphs: Graphset
using Test
using Random, LinearAlgebra
using Base.Threads

rng = Random.Xoshiro(0) 

@testset verbose=true "NautyGraphs" begin
    include("densenautygraph.jl")
    include("nauty.jl")
    include("graphset.jl")
    include("utils.jl")
    include("interface.jl")
    VERSION >= v"1.12" && include("aqua.jl")
    VERSION >= v"1.12" && include("jet.jl")
end
