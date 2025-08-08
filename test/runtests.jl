using NautyGraphs, Graphs
using NautyGraphs: Graphset
using Test
using Random, LinearAlgebra
using Base.Threads

@testset verbose=true "NautyGraphs" begin
    include("densenautygraph.jl")
    include("nauty.jl")
    include("graphset.jl")
    include("utils.jl")
    VERSION >= v"1.9-" && include("interface.jl")
    include("aqua.jl")
    include("jet.jl")
end
