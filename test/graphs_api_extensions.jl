@testset "Graphs API extensions" begin
    g = path_graph(5)
    h = path_graph(5)
    k = star_graph(5)

    @test has_isomorph(g, h, NautyAlg(; sparse=true))
    @test has_isomorph(g, h, NautyAlg(; sparse=false))

    @test !has_isomorph(g, k, NautyAlg(; sparse=true))
    @test !has_isomorph(g, k, NautyAlg(; sparse=false))

    @test count_isomorph(g, h, NautyAlg(; sparse=true)) == count_isomorph(g, h, Graphs.Experimental.VF2()) == 2
    @test count_isomorph(g, k, NautyAlg(; sparse=false)) == count_isomorph(g, k, Graphs.Experimental.VF2()) == 0

    g = Graph(5)
    h = Graph(5)
    k = star_graph(5)

    lab1 = 1:5
    lab2 = [3, 2, 5, 1, 4]
    lab3 = 2:6

    @test has_isomorph(g, h, NautyAlg(; sparse=true); vertex_labels=(lab1, lab2))
    @test !has_isomorph(g, k, NautyAlg(; sparse=true); vertex_labels=(lab1, lab2))
    @test !has_isomorph(g, h, NautyAlg(; sparse=false); vertex_labels=(lab1, lab3))

    @test count_isomorph(g, h, NautyAlg(; sparse=true); vertex_labels=(lab1, lab2)) == count_isomorph(g, h, Graphs.Experimental.VF2(); vertex_relation=(v,w)->lab1[v]==lab2[w]) == 1
    @test count_isomorph(g, k, NautyAlg(; sparse=true); vertex_labels=(lab1, lab2)) == count_isomorph(g, k, Graphs.Experimental.VF2(); vertex_relation=(v,w)->lab1[v]==lab2[w]) == 0
    @test count_isomorph(g, h, NautyAlg(; sparse=false); vertex_labels=(lab1, lab3)) == count_isomorph(g, h, Graphs.Experimental.VF2(); vertex_relation=(v,w)->lab1[v]==lab3[w]) == 0
end