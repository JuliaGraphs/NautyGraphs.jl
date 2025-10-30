@testset "nauty" begin
    verylarge_g = NautyGraph(50)

    _, autg = nauty(verylarge_g)
    @test autg.n > typemax(Int64)

    g1 = NautyGraph(4)
    add_edge!(g1, 1, 2)
    add_edge!(g1, 2, 3)
    add_edge!(g1, 2, 4)

    h1 = NautyGraph(4)
    add_edge!(h1, 3, 4)
    add_edge!(h1, 4, 1)
    add_edge!(h1, 4, 2)

    @test g1 ≃ h1
    @test canonical_id(g1) == canonical_id(h1)

    g1_16 = NautyGraph{UInt16}(g1)
    @test g1_16 == g1
    @test g1_16 ≃ g1

    g1_32 = NautyGraph{UInt32}(g1)
    @test g1_32 == g1_16
    @test g1_32 ≃ g1_16
    @test g1_32 == g1
    @test g1_32 ≃ g1

    k1 = copy(g1)
    rem_edge!(k1, 2, 3)
    @test !(k1 ≃ h1)
    @test canonical_id(k1) != canonical_id(h1)

    f1 = copy(g1)
    rem_vertex!(f1, 2)
    @test !(f1 ≃ h1)
    @test canonical_id(f1) != canonical_id(h1)

    g2 = NautyGraph(4; vertex_labels=[0, 0, 1, 1])
    add_edge!(g2, 1, 2)
    add_edge!(g2, 2, 3)
    add_edge!(g2, 2, 4)

    h2 = NautyGraph(4; vertex_labels=[1, 1, 0, 0])
    add_edge!(h2, 3, 4)
    add_edge!(h2, 4, 1)
    add_edge!(h2, 4, 2)

    @test g2 ≃ h2
    @test canonical_id(g2) == canonical_id(h2)

    g2_16 = NautyGraph{UInt16}(g2)
    @test g2_16 == g2
    @test g2_16 ≃ g2

    g2_32 = NautyGraph{UInt32}(g2)
    @test g2_32 == g2_16
    @test g2_32 ≃ g2_16
    @test g2_32 == g2
    @test g2_32 ≃ g2

    k2 = NautyGraph(4; vertex_labels=[1, 0, 0, 1])
    add_edge!(k2, 3, 4)
    add_edge!(k2, 4, 1)
    add_edge!(k2, 4, 2)

    @test !(g2 ≃ k2)
    @test canonical_id(g2) != canonical_id(k2)

    g3 = NautyGraph(6)
    add_edge!(g3, 1, 2)
    add_edge!(g3, 4, 1)
    add_edge!(g3, 3, 2)
    add_edge!(g3, 2, 5)
    add_edge!(g3, 1, 5)

    h3 = copy(g3)
    canonize!(h3)

    @test g3 ≃ h3
    @test canonical_id(g3) == canonical_id(h3)

    k3 = NautyGraph(6)
    add_edge!(k3, 6, 2)
    add_edge!(k3, 5, 6)
    add_edge!(k3, 3, 2)
    add_edge!(k3, 2, 4)
    add_edge!(k3, 6, 4)

    @test k3 ≃ g3
    @test canonical_id(k3) == canonical_id(g3)

    m3 = copy(k3)
    canonize!(m3)
    @test adjacency_matrix(m3) == adjacency_matrix(h3)


    g4 = NautyGraph(3; vertex_labels=[1, 2, 3])
    h4 = NautyGraph(3; vertex_labels=[1, 2, 3])
    add_edge!(g4, 1, 2)
    add_edge!(h4, 1, 2)

    @test g4 == h4
    @test Base.hash(g4) == Base.hash(h4)
    # dont do this during normal use!
    g4.iscanon = true
    @test Base.hash(g4) == Base.hash(h4)

    g5 = NautyGraph(10; vertex_labels=10:-1:1)
    add_edge!(g5, 1, 2)
    add_edge!(g5, 5, 2)
    add_edge!(g5, 6, 7)
    add_edge!(g5, 8, 1)
    add_edge!(g5, 9, 10)

    canon5 = copy(g5)
    canonize!(canon5)

    canonperm5 = canonical_permutation(g5)
    @test canon5.labels == g5.labels[canonperm5]

    # Just test that multithreading doesnt lead to errors
    thread_gs = [copy(g4) for i in 1:10]
    vals = Any[nothing for i in 1:10]
    @threads for i in eachindex(vals, thread_gs)
        for j in 1:20
            vals[i] = nauty(thread_gs[i])
            sleep(0.01)
        end
    end
    @test true

    gnoloop = NautyGraph(5)
    add_edge!(gnoloop, 1, 2)
    add_edge!(gnoloop, 3, 5)
    add_edge!(gnoloop, 5, 2)

    gloop = copy(gnoloop)
    add_edge!(gloop, 1, 1)

    @test_nowarn nauty(gloop)
    @test !is_isomorphic(gnoloop, gloop)

    gdinoloop = NautyDiGraph(5)
    add_edge!(gdinoloop, 1, 2)
    add_edge!(gdinoloop, 3, 5)
    add_edge!(gdinoloop, 5, 2)

    gdiloop = copy(gdinoloop)
    add_edge!(gdiloop, 1, 1)

    @test_nowarn nauty(gdiloop)
    @test !is_isomorphic(gdinoloop, gdiloop)

    # Test that canonical_id doesnt error for large graphs
    glarge = NautyGraph(200)
    canonical_id(glarge)

    g6 = NautyDiGraph([Edge(2, 1), Edge(3, 1), Edge(1, 4)])
    nauty(g6; canonize=false)
    @test !iscanon(g6)

    g7 = NautyDiGraph([Edge(2, 1), Edge(3, 1), Edge(1, 4)])
    nauty(g7; canonize=true)

    @test iscanon(g7)
    @test canonical_id(g6) == canonical_id(g7)

    g8 = NautyDiGraph([Edge(2, 1), Edge(3, 1), Edge(1, 4)])
    @test !iscanon(g8)
    canonize!(g8)
    @test iscanon(g8)


    # Test filtering via canonize! and Sets
    g1 = NautyGraph(5)
    add_edge!(g1, 1, 2)
    
    g2 = NautyGraph(5)
    add_edge!(g2, 3, 4)
    
    g3 = NautyGraph(6)

    s1 = Set([g1, g2, g3])
    @test length(s1) == 3

    canonize!(g1)
    canonize!(g2)
    canonize!(g3)

    s2 = Set([g1, g2, g3])
    @test length(s2) == 2
    @test g1 in s2
    @test g2 in s2
    @test g3 in s2
end