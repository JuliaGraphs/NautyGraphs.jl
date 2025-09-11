using NautyGraphs, Graphs
using NautyGraphs: Graphset
using Test
using Random, LinearAlgebra
using Base.Threads

@testset verbose=true "NautyGraphs" begin
    include("densenautygraph.jl")
    include("nauty.jl")
    include("graphset.jl")
    include("hashing.jl")
    VERSION >= v"1.9-" && include("interface.jl")
    include("aqua.jl")
    VERSION >= v"1.10" && include("jet.jl")
end
