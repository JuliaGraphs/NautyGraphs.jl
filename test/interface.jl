using Pkg; Pkg.add(url="https://github.com/JuliaGraphs/GraphsInterfaceChecker.jl")
using GraphsInterfaceChecker, Interfaces

@testset "interface" begin 
    test_graphs_dense = [NautyGraph(0), 
                    NautyDiGraph(0), 
                    NautyGraph([1 0 1; 0 0 0; 1 0 1]),
                    NautyDiGraph([0 0 1; 1 0 0; 1 1 1])]

    @implements AbstractGraphInterface{(:mutation)} DenseNautyGraph test_graphs_dense
    @test Interfaces.test(AbstractGraphInterface, DenseNautyGraph)

    test_graphs_sparse = [SpNautyGraph(0), 
                    SpNautyDiGraph(0), 
                    SpNautyGraph([1 0 1; 0 0 0; 1 0 1]),
                    SpNautyDiGraph([0 0 1; 1 0 0; 1 1 1])]

    @implements AbstractGraphInterface{(:mutation)} SparseNautyGraph test_graphs_sparse
    @test Interfaces.test(AbstractGraphInterface, SparseNautyGraph)
end
