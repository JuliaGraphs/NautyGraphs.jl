using JET

@testset "JET" begin 
   test_package(NautyGraphs)

   @test_opt NautyGraph(10)
   @test_opt NautyDiGraph(10)

   A = [1 0 1; 0 1 0; 1 1 1]
   @test_opt NautyDiGraph(A)

   g = NautyDiGraph(5; vertex_labels=1:5)
   h = NautyGraph(g)
   @test_opt copy(g)
   @test_opt NautyDiGraph(g)

   add_edge!(g, 2, 5)

   @test_opt add_edge!(g, 1, 2)
   @test_opt add_vertex!(g)
   @test_opt add_vertex!(g; vertex_label=5)
   @test_opt rem_vertex!(g, 3)
   @test_opt rem_edge!(g, 2, 5)
   @test_opt outneighbors(g, 1)
   @test_opt inneighbors(g, 1)
   @test_opt collect(edges(g))
   @test_opt blockdiag(g, h)

   @test_opt nauty(g)
   @test_opt canonize!(g)
end
