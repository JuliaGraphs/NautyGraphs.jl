using JET

@testset "JET" begin 
   test_package(NautyGraphs; target_modules=(NautyGraphs,))

   @test_opt target_modules=(NautyGraphs,) NautyGraph(10)
   @test_opt target_modules=(NautyGraphs,) NautyDiGraph(10)
   @test_opt target_modules=(NautyGraphs,) SpNautyGraph(10)
   @test_opt target_modules=(NautyGraphs,) SpNautyDiGraph(10)

   A = [1 0 1; 0 1 0; 1 1 1]
   @test_opt target_modules=(NautyGraphs,) NautyDiGraph(A)
   @test_opt target_modules=(NautyGraphs,) SpNautyDiGraph(A)

   g = NautyDiGraph(5; vertex_labels=1:5)
   h = NautyGraph(g)
   @test_opt target_modules=(NautyGraphs,) copy(g)
   @test_opt target_modules=(NautyGraphs,) NautyDiGraph(g)

   @test_opt target_modules=(NautyGraphs,) add_edge!(g, 1, 2)
   @test_opt target_modules=(NautyGraphs,) add_vertex!(g)
   @test_opt target_modules=(NautyGraphs,) add_vertex!(g; vertex_label=5)
   @test_opt target_modules=(NautyGraphs,) rem_vertex!(g, 3)
   @test_opt target_modules=(NautyGraphs,) rem_edge!(g, 2, 5)
   @test_opt target_modules=(NautyGraphs,) outneighbors(g, 1)
   @test_opt target_modules=(NautyGraphs,) inneighbors(g, 1)
   @test_opt target_modules=(NautyGraphs,) collect(edges(g))
   @test_opt target_modules=(NautyGraphs,) blockdiag(g, h)

   @test_opt target_modules=(NautyGraphs,) nauty(g)
   @test_opt target_modules=(NautyGraphs,) canonize!(g)
   @test_opt target_modules=(NautyGraphs,) canonical_id(g)


   k = SpNautyDiGraph(5; vertex_labels=1:5)
   l = SpNautyGraph(g)
   @test_opt target_modules=(NautyGraphs,) copy(k)
   @test_opt target_modules=(NautyGraphs,) NautyDiGraph(k)

   @test_opt target_modules=(NautyGraphs,) add_edge!(k, 1, 2)
   @test_opt target_modules=(NautyGraphs,) add_vertex!(k)
   @test_opt target_modules=(NautyGraphs,) add_vertex!(k; vertex_label=5)
   @test_opt target_modules=(NautyGraphs,) rem_vertex!(k, 3)
   @test_opt target_modules=(NautyGraphs,) rem_edge!(k, 2, 5)
   @test_opt target_modules=(NautyGraphs,) outneighbors(k, 1)
   @test_opt target_modules=(NautyGraphs,) inneighbors(k, 1)
   @test_opt target_modules=(NautyGraphs,) collect(edges(k))
   @test_opt target_modules=(NautyGraphs,) blockdiag(k, l)

   @test_opt target_modules=(NautyGraphs,) nauty(k)
   @test_opt target_modules=(NautyGraphs,) canonize!(k)
end
