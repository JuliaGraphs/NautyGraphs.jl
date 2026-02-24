@testset verbose=true "nauty" begin
    @testset "unlabeled" begin
        es1_A = [Edge(1, 2), Edge(2, 3), Edge(2, 4)]
        es1_B = [Edge(3, 4), Edge(4, 1), Edge(4, 2)]

        for G in (NautyGraph, SpNautyGraph)
            g1 = G(es1_A)
            h1 = G(es1_B)
            @test g1 != h1
            @test g1 ≃ h1
            @test canonical_id(g1) == canonical_id(h1)

            k1 = copy(g1)
            rem_edge!(k1, 2, 3)
            @test !(k1 ≃ h1)
            @test canonical_id(k1) != canonical_id(h1)

            f1 = copy(g1)
            rem_vertex!(f1, 2)
            @test !(f1 ≃ h1)
            @test canonical_id(f1) != canonical_id(h1)

            es2_A = [Edge(1, 2), Edge(4, 1), Edge(3, 2), Edge(2, 5), Edge(1, 5)]

            g2 = G(6)
            foreach(e->add_edge!(g2, e), es2_A)

            h2 = copy(g2)
            canonize!(h2)
            @test g2 ≃ h2
            @test canonical_id(g2) == canonical_id(h2)

            es2_B = [Edge(6, 2), Edge(5, 6), Edge(3, 2), Edge(2, 4), Edge(6, 4)]

            k2 = G(es2_B)
            @test k2 ≃ g2
            @test canonical_id(k2) == canonical_id(g2)

            m2 = copy(k2)
            canonize!(m2)
            @test adjacency_matrix(m2) == adjacency_matrix(h2)

            # test that we dont error for empty graphs
            gempty = G(0)
            canonical_id(gempty)
        end
    end

    @testset "labeled" begin
        for G in (NautyGraph, SpNautyGraph)
            g = G(4; vertex_labels=[0, 0, 1, 1])
            add_edge!(g, 1, 2)
            add_edge!(g, 2, 3)
            add_edge!(g, 2, 4)

            h = G(4; vertex_labels=[1, 1, 0, 0])
            add_edge!(h, 3, 4)
            add_edge!(h, 4, 1)
            add_edge!(h, 4, 2)

            @test g ≃ h
            @test canonical_id(g) == canonical_id(h)
            
            k = G(4; vertex_labels=[1, 0, 0, 1])
            add_edge!(k, 3, 4)
            add_edge!(k, 4, 1)
            add_edge!(k, 4, 2)

            @test !(g ≃ k)
            @test canonical_id(g) != canonical_id(k)

            g2 = G(10; vertex_labels=10:-1:1)
            add_edge!(g2, 1, 2)
            add_edge!(g2, 5, 2)
            add_edge!(g2, 6, 7)
            add_edge!(g2, 8, 1)
            add_edge!(g2, 9, 10)

            canon2 = copy(g2)
            canonize!(canon2)

            canonperm2 = canonical_permutation(g2)
            @test labels(canon2) == labels(g2)[canonperm2]
        end
    end

    @testset "directed" begin
        es1_A = [Edge(1, 2), Edge(2, 3), Edge(3, 4)]
        es1_B = [Edge(4, 2), Edge(2, 3), Edge(3, 1)]

        for G in (NautyDiGraph, SpNautyDiGraph)
            g1 = G(es1_A)
            h1 = G(es1_B)
            @test g1 != h1
            @test g1 ≃ h1
            @test canonical_id(g1) == canonical_id(h1)

            k1 = copy(g1)
            rem_edge!(k1, 2, 3)
            @test !(k1 ≃ h1)
            @test canonical_id(k1) != canonical_id(h1)

            f1 = copy(g1)
            rem_vertex!(f1, 2)
            @test !(f1 ≃ h1)
            @test canonical_id(f1) != canonical_id(h1)
        end
    end

    @testset "hash" begin
        for G in (NautyGraph, NautyDiGraph, SpNautyGraph, SpNautyDiGraph)
            g = NautyGraph(3; vertex_labels=[1, 2, 3])
            h = NautyGraph(3; vertex_labels=[1, 2, 3])
            add_edge!(g, 1, 2)
            add_edge!(h, 1, 2)

            @test !NautyGraphs.iscanon(g)
            @test !NautyGraphs.iscanon(h)

            @test g == h
            @test Base.hash(g) == Base.hash(h)
            # dont do this during normal use!
            g.iscanon = true
            @test Base.hash(g) == Base.hash(h)
        end
    end

    @testset "loops" begin
        for G in (NautyGraph, SpNautyGraph)
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
        end
    end

    @testset "canonize" begin
        for G in (NautyDiGraph, SpNautyDiGraph)
            g1 = G([Edge(2, 1), Edge(3, 1), Edge(1, 4)])
            nauty(g1; canonize=false)
            @test !iscanon(g1)

            g2 = G([Edge(2, 1), Edge(3, 1), Edge(1, 4)])
            nauty(g2; canonize=true)

            @test iscanon(g2)
            @test canonical_id(g1) == canonical_id(g2)

            g3 = G([Edge(2, 1), Edge(3, 1), Edge(1, 4)])
            @test !iscanon(g3)
            canonize!(g3)
            @test iscanon(g3)
        end

        for G in (NautyGraph, NautyDiGraph, SpNautyGraph, SpNautyDiGraph)
            # Test filtering via canonize! and Sets
            g1 = G(5)
            add_edge!(g1, 1, 2)

            g2 = G(5)
            add_edge!(g2, 3, 4)

            g3 = G(6)

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
    end

    @testset "iscanon" begin
        for G in (NautyGraph, NautyDiGraph, SpNautyGraph, SpNautyDiGraph)
            g = G(; vertex_labels=1:5)

            @test !iscanon(g)
            canonize!(g)
            @test iscanon(g)

            add_edge!(g, 1, 2)
            @test !iscanon(g)
            canonize!(g)
            @test iscanon(g)

            add_vertex!(g; vertex_label=6)
            @test !iscanon(g)
            canonize!(g)
            @test iscanon(g)

            rem_vertex!(g, 3)
            @test !iscanon(g)
            canonize!(g)
            @test iscanon(g)

            rem_edge!(g, only(edges(g)))
            @test !iscanon(g)
            canonize!(g)
            @test iscanon(g)

            setlabel!(g, 1, 99)
            @test !iscanon(g)
            canonize!(g)
            @test iscanon(g)

            setlabels!(g, 1:5)
            @test !iscanon(g)
            canonize!(g)
            @test iscanon(g)
        end
    end

        @testset "thread safety" begin
        g = NautyGraph(3; vertex_labels=[1, 2, 3])
        add_edge!(g, 1, 2)

        thread_gs = [copy(g) for i in 1:10]
        vals = Any[nothing for i in 1:10]
        @threads for i in eachindex(vals, thread_gs)
            for j in 1:20
                vals[i] = nauty(thread_gs[i])
                sleep(0.01)
            end
        end
        @test true
    end

        @testset "wordtypes" begin
        g = NautyGraph([Edge(1, 2), Edge(2, 3), Edge(2, 4)])
        g16 = NautyGraph{UInt16}(g)
        @test g16 == g
        @test g16 ≃ g

        g32 = NautyGraph{UInt32}(g)
        @test g32 == g16
        @test g32 ≃ g16
        @test g32 == g
        @test g32 ≃ g

        g = NautyGraph(4; vertex_labels=[0, 0, 1, 1])
        add_edge!(g, 1, 2)
        add_edge!(g, 2, 3)
        add_edge!(g, 2, 4)

        g16 = NautyGraph{UInt16}(g)
        @test g16 == g
        @test g16 ≃ g

        g32 = NautyGraph{UInt32}(g)
        @test g32 == g16
        @test g32 ≃ g16
        @test g32 == g
        @test g32 ≃ g
    end

    @testset "overflow" begin
        verylarge_g = NautyGraph(50)
        _, autg = nauty(verylarge_g)
        @test autg.n > typemax(Int64)

        verylarge_g = SpNautyGraph(50)
        _, autg = nauty(verylarge_g)
        @test autg.n > typemax(Int64)

        # Test that canonical_id doesnt error for large graphs
        glarge = NautyGraph(200)
        canonical_id(glarge)
    end
end

