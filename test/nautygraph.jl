function vertexedge_test(g, ng, spng; edge_equal, vertex_equal)
    # test whether attributes of ng and spng are equal to each other, and either equal or unequal to g
    edge_comp = edge_equal ? Base.:(==) : Base.:(!=)
    @test edge_comp(edges(g), edges(ng))
    @test edge_comp(edges(g), edges(spng))
    @test edge_comp(collect(edges(g)), collect(edges(ng)))
    @test edge_comp(collect(edges(g)), collect(edges(spng)))
    @test edge_comp(ne(g), ne(ng))
    @test edge_comp(ne(g), ne(spng))
    @test edges(ng) == edges(spng)

    vert_comp = vertex_equal ? Base.:(==) : Base.:(!=)
    @test vert_comp(vertices(g), vertices(ng))
    @test vert_comp(vertices(g), vertices(spng))
    @test vert_comp(nv(g), nv(ng))
    @test vert_comp(nv(g), nv(spng))
    @test vertices(ng) == vertices(spng)

    adj_equal = edge_equal && vertex_equal
    adj_comp = adj_equal ? Base.:(==) : Base.:(!=)
    @test adj_comp(adjacency_matrix(g), adjacency_matrix(ng))
    @test adj_comp(adjacency_matrix(g), adjacency_matrix(spng))
    @test adjacency_matrix(ng) == adjacency_matrix(spng)
    return
end

function testgraphcollection(gdata; directed=nothing, wt=UInt)
    if isnothing(directed)
        return Iterators.flatten((((Graph(A), NautyGraph{wt}(A), SpNautyGraph(A)) for A in gdata), 
                                  ((DiGraph(A), NautyDiGraph{wt}(A), SpNautyDiGraph(A)) for A in gdata)))
    elseif directed
        return ((DiGraph(A), NautyDiGraph{wt}(A), SpNautyDiGraph(A)) for A in gdata)
    else
        return ((Graph(A), NautyGraph{wt}(A), SpNautyGraph(A)) for A in gdata)
    end
end

@testset verbose=true "nautygraph" begin
    @testset "loops" begin
        A0 = [1 0 0; 0 0 0; 0 0 0]
        A1 = [1 0 0; 0 1 0; 0 0 0]

        for (g, ng, spng) in (testgraphcollection([A0]; directed=false)..., testgraphcollection([A1]; directed=true)...)
            vertexedge_test(g, ng, spng; edge_equal=true, vertex_equal=true)

            add_edge!(g, 1, 2)
            vertexedge_test(g, ng, spng; edge_equal=false, vertex_equal=true)

            add_edge!(ng, 1, 2)
            add_edge!(spng, 1, 2)
            vertexedge_test(g, ng, spng; edge_equal=true, vertex_equal=true)

            rem_vertex!(g, 3)
            vertexedge_test(g, ng, spng; edge_equal=true, vertex_equal=false)

            rem_vertex!(ng, 3)
            rem_vertex!(spng, 3)
            vertexedge_test(g, ng, spng; edge_equal=true, vertex_equal=true)

            rem_edge!(g, 1, 2)
            vertexedge_test(g, ng, spng; edge_equal=false, vertex_equal=true)

            rem_edge!(ng, 1, 2)
            rem_edge!(spng, 1, 2)
            vertexedge_test(g, ng, spng; edge_equal=true, vertex_equal=true)
        end
    end

    @testset "empty" begin
        for (_, ng, spng) in testgraphcollection([0])
            ng = NautyGraph(0)
            spng = SpNautyGraph(0)
            @test nv(ng) == 0
            @test ne(ng) == 0
            @test nv(spng) == 0
            @test ne(spng) == 0
            
            empty_edges_g = collect(edges(ng))
            @test isempty(empty_edges_g)
            @test eltype(empty_edges_g) == Graphs.SimpleGraphs.SimpleGraphEdge{Int}

            empty_edges_spng = collect(edges(spng))
            @test isempty(empty_edges_spng)
            @test eltype(empty_edges_spng) == Graphs.SimpleGraphs.SimpleGraphEdge{Int}

            @test empty_edges_g == empty_edges_spng
        end
    end

    @testset "membership" begin
        g0 = erdos_renyi(70, 100; rng=rng)
        ng = NautyGraph(g0)
        ngd = NautyDiGraph(g0)
        spng = SpNautyGraph(g0)
        spngd = SpNautyDiGraph(g0)

        @test ngd.graphset == ng.graphset
        @test ngd.graphset == ng.graphset

        @test nv(ng) == nv(spng) == 70
        @test ne(ng) == ne(spng) == 100
        @test vertices(ng) == vertices(spng) == Base.OneTo(70)

        @test nv(ngd) == nv(spngd) == 70
        @test ne(ngd) == ne(spngd) == 200
        @test vertices(ngd) == vertices(spngd) == Base.OneTo(70)

        for edge in edges(ng)
            @test has_edge(ng, edge)
        end
        for edge in edges(ngd)
            @test has_edge(ngd, edge)
        end
        for edge in edges(spng)
            @test has_edge(spng, edge)
        end
        for edge in edges(spngd)
            @test has_edge(spngd, edge)
        end
        for edge in edges(g0)
            @test has_edge(ng, edge)
            @test has_edge(spng, edge)
        end
        for vertex in vertices(g0)
            @test has_vertex(ng, vertex)
            @test has_vertex(spng, vertex)
            @test has_vertex(ngd, vertex)
            @test has_vertex(spngd, vertex)
        end

        @test has_edge(ng, 1, 71) == false
        @test has_edge(ng, 75, 5) == false
        @test has_edge(ngd, 1, 71) == false
        @test has_edge(ngd, 75, 5) == false

        @test has_edge(spng, 1, 71) == false
        @test has_edge(spng, 75, 5) == false
        @test has_edge(spngd, 1, 71) == false
        @test has_edge(spngd, 75, 5) == false

        @test !has_vertex(ng, 0)
        @test !has_vertex(spng, 0)
        @test !has_vertex(ngd, 0)
        @test !has_vertex(spngd, 0)

        @test !has_vertex(ng, -5)
        @test !has_vertex(spng, -5)
        @test !has_vertex(ngd, -5)
        @test !has_vertex(spngd, -5)

        @test !has_vertex(ng, 71)
        @test !has_vertex(spng, 71)
        @test !has_vertex(ngd, 71)
        @test !has_vertex(spngd, 71)
    end

    @testset "degrees" begin
        g0 = erdos_renyi(50, 200; rng=rng)
        ng = NautyGraph(g0)
        ngd = NautyDiGraph(g0)
        spng = SpNautyGraph(g0)
        spngd = SpNautyDiGraph(g0)

        for vertex in vertices(g0)
            @test outdegree(ng, vertex) == length(collect(outneighbors(ng, vertex)))
            @test indegree(ng, vertex) == length(collect(inneighbors(ng, vertex)))
        
            @test outdegree(spng, vertex) == length(collect(outneighbors(spng, vertex)))
            @test indegree(spng, vertex) == length(collect(inneighbors(spng, vertex)))

            @test outdegree(ngd, vertex) == length(collect(outneighbors(ngd, vertex)))
            @test indegree(ngd, vertex) == length(collect(inneighbors(ngd, vertex)))
        
            @test outdegree(spngd, vertex) == length(collect(outneighbors(spngd, vertex)))
            @test indegree(spngd, vertex) == length(collect(inneighbors(spngd, vertex)))
        end

        g = NautyDiGraph([Edge(1, 2), Edge(2, 3), Edge(2, 4)])
        @test outneighbors(g, 2) == [3, 4]
        @test outneighbors(g, 1) == [2]

        @test inneighbors(g, 2) == [1]
        @test inneighbors(g, 1) == []
    end

    @testset "equality" begin
        @test NautyGraph(0) == NautyGraph(0)
        @test NautyGraph(5) == NautyGraph(5)
        @test NautyDiGraph(0) == NautyDiGraph(0)
        @test NautyDiGraph(5) == NautyDiGraph(5)

        @test SpNautyGraph(0) == SpNautyGraph(0)
        @test SpNautyDiGraph(5) == SpNautyDiGraph(5)
        @test SpNautyDiGraph(0) == SpNautyDiGraph(0)
        @test SpNautyDiGraph(5) == SpNautyDiGraph(5)

        es = [Edge(1, 2), Edge(2, 3), Edge(2, 4)]
        g = NautyDiGraph(4)
        for e in es
            add_edge!(g, e)
        end

        k = NautyDiGraph(es)
        
        @test g == k

        setlabels!(g, [1, 2, 3, 4])
        setlabels!(k, [1, 2, 3, 4])

        @test g == k

        setlabels!(k, [1, 2, 3, 5])

        @test g != k

        add_edge!(g, 1, 4)

        @test g != k
    end

    @testset "invalid modifications" begin
        es = [Edge(1, 2), Edge(2, 3), Edge(2, 4)]

        for (_, ng, spng) in testgraphcollection([es]; directed=true)
            for g in (ng, spng)
                g2 = copy(g)

                @test add_edge!(g2, 2, 5) == false
                @test g2 == g

                @test add_edge!(copy(g), 1, 3) == true
                @test add_edge!(copy(g), 1, 2) == false

                @test rem_edge!(copy(g), 1, 3) == false
                @test rem_edge!(copy(g), 1, 2) == true
                @test rem_edge!(copy(g), Edge(1, 2)) == true

                @test add_vertices!(copy(g), 3; vertex_labels=[1, 2, 3]) == 3

                @test rem_vertex!(copy(g), 5) == false
            end
        end
    end

    @testset "labels" begin
        g1 = NautyDiGraph([Edge(1, 2), Edge(2, 3), Edge(2, 4)])
        @test labels(g1) == vcat([0, 0, 0, 0])

        g2 = copy(g1)
        setlabels!(g2, [1, 4, 5, 10])
        @test labels(g2) == [1, 4, 5, 10]

        setlabel!(g2, 1, 99)
        @test labels(g2) == [99, 4, 5, 10]

        g3 = copy(g2)
        @test labels(g3) == [99, 4, 5, 10]

        rem_vertices!(g3, [1, 3])
        @test labels(g3) == [4, 10]
        @test label(g3, 1) == 4

        ####

        gl1 = NautyGraph(3; vertex_labels=[1,2,3])
        gl2 = NautyGraph(3)        
        gl3 = NautyGraph(3)

        setlabels!(gl2, [1,2,3])
        foreach(1:3) do i
            setlabel!(gl3, i, i)
        end

        @test labels(gl1) == labels(gl2) == labels(gl3)
        @test label(gl1, 1) == label(gl2, 1)
        @test label(gl1, 2) == label(gl2, 2)

        gl4 = copy(gl1)
        add_edge!(gl4, 1, 2)
        gl4_id1 = canonical_id(gl4)
        setlabels!(gl4, [3, 4, 5])
        gl4_id2 = canonical_id(gl4)

        @test gl4_id1 != gl4_id2

        canonize!(gl4)
        @test NautyGraphs.iscanon(gl4)

        setlabels!(gl4, [3, 4, 5])
        @test !NautyGraphs.iscanon(gl4)

        canonize!(gl4)
        @test NautyGraphs.iscanon(gl4)

        setlabel!(gl4, 3, 3)
        @test !NautyGraphs.iscanon(gl4)

        gl5 = copy(gl1)
        add_edge!(gl5, 1, 2)
        gl5_id1 = canonical_id(gl5)
        setlabel!(gl5, 3, 6)
        gl5_id2 = canonical_id(gl5)
        
        @test gl5_id1 != gl5_id2

        gls1 = NautyGraph(; vertex_labels=[1, 2, 3, 4])
        gls2 = NautyGraph(4; vertex_labels=[1, 2, 3, 4])
        @test gls1 == gls2

        add_vertices!(gls1, 2; vertex_labels=[5, 6])
        add_vertices!(gls2; vertex_labels=[5, 6])

        @test gls1 == gls2

        glab = NautyGraph(5; vertex_labels=1:5)
        add_edge!(glab, 1, 2)
        add_edge!(glab, 1, 3)
        add_edge!(glab, 1, 4)
        add_edge!(glab, 1, 5)
        add_edge!(glab, 2, 5)

        gind1 = glab[[1, 5, 2]]
        @test labels(gind1) == [1, 5, 2]

        gind2 = glab[[Edge(1, 2), Edge(1, 4)]]
        @test labels(gind2) == [1, 2, 4]
    end

    @testset "copy" begin
        es = [Edge(1, 2), Edge(2, 1), Edge(2, 3), Edge(3, 2)]
        for (_, ng, spng) in testgraphcollection([es])
            for g in (ng, spng)
                h = typeof(g)(nv(g))

                copy!(h, g)
                if h isa DenseNautyGraph
                    @test h.graphset == g.graphset
                    @test h.graphset.n == g.graphset.n
                    @test h.graphset.m == g.graphset.m
                end

                @test ne(h) == ne(g)
                @test nv(h) == nv(g)
                @test edges(h) == edges(g)
                @test vertices(h) == vertices(g)
                @test labels(h) == labels(g)
                @test iscanon(h) == iscanon(g)
                @test h == g
            end
        end
    end

    @testset "blockdiag" begin
        es = [Edge(1, 2), Edge(2, 1), Edge(2, 3), Edge(3, 2)]
        for (_, ng, spng) in testgraphcollection([es])
            for g in (ng, spng)
                g0 = is_directed(g) ? DiGraph(g) : Graph(g)

                bb_ng = blockdiag(g, g)
                bb_g = typeof(g)(blockdiag(g0, g0))
                @test bb_ng == bb_g
            end
        end
    end

    ## Edge iterator 
    @testset "edge iterator" begin
        A = [0 1 0 0;
             1 0 1 0;
             0 1 0 0;
             0 0 0 0]
        for (g0, g, sg) in testgraphcollection([A])
            @test edges(g) == edges(g0)
            @test edges(sg) == edges(g0)
            @test edges(g) == edges(sg)

            g1 = copy(g0)
            add_edge!(g1, 1, nv(g1))
            @test edges(g) != edges(g1)
            @test edges(sg) != edges(g1)

            g2 = copy(g0)
            add_edge!(g2, nv(g2), 1)
            @test edges(g) != edges(g2)
            @test edges(sg) != edges(g2)

            g3 = copy(g0)
            add_edge!(g3, nv(g3), nv(g3))
            @test edges(g) != edges(g3)
            @test edges(sg) != edges(g3)

            g4 = copy(g0)
            add_edge!(g4, 1, 1)
            @test edges(g) != edges(g4)
            @test edges(sg) != edges(g4)

            g5 = copy(g0)
            add_vertex!(g5)
            @test edges(g) == edges(g5)
            @test edges(sg) == edges(g5)

            add_vertex!(g)
            @test edges(g) == edges(sg)

            add_vertex!(sg)
            @test edges(g) == edges(sg)
            @test edges(g) == edges(g0)
            @test edges(sg) == edges(g0)
            @test edges(g) == edges(g5)
            @test edges(sg) == edges(g5)

            add_vertex!(g)
            add_vertex!(sg)
            add_edge!(g, nv(g), nv(g))
            @test edges(g) != edges(sg)

            add_edge!(sg, nv(g), nv(g))
            @test edges(g) == edges(sg)
            @test edges(g) != edges(g0)
            @test edges(sg) != edges(g0)
        end
    end

    @testset "spray" begin
        nverts = [1, 2, 3, 4, 5, 10, 20, 31, 32, 33, 50, 63, 64, 
                65, 100, 122, 123, 124, 125, 126, 200, 500, 1000]
        As = [rand(rng, 0:1, i, i) for i in nverts]

        wtypes = [UInt16, UInt32, UInt64]

        gs = []
        ngs_wt = []
        spngs = []
        for A in As
            Asym = Int.((A + A') .> 0)

            push!(gs, Graph(Asym))
            push!(gs, DiGraph(A))

            push!(spngs, SpNautyGraph(Asym))
            push!(spngs, SpNautyDiGraph(A))

            push!(ngs_wt, [NautyGraph{wt}(Asym) for wt in wtypes])
            push!(ngs_wt, [NautyDiGraph{wt}(A) for wt in wtypes])
        end

        for (g, ngs, spng) in zip(gs, ngs_wt, spngs), ng in ngs
            g1, ng1, spng1 = copy(g), copy(ng), copy(spng)
            g2, ng2, spng2 = copy(g), copy(ng), copy(spng)
            g3, ng3, spng3 = copy(g), copy(ng), copy(spng)
            g4, ng4, spng4 = copy(g), copy(ng), copy(spng)

            vertexedge_test(g1, ng1, spng1; edge_equal=true, vertex_equal=true)

            rv = sort(unique(rand(rng, 1:nv(ng1), 4)))
            rem_vertices!(g1, rv, keep_order=true)

            @test adjacency_matrix(g1) != adjacency_matrix(ng1)
            @test adjacency_matrix(g1) != adjacency_matrix(spng1)
            @test nv(g1) != nv(ng1)
            @test nv(g1) != nv(spng1)
            @test vertices(g1) != vertices(ng1)
            @test vertices(g1) != vertices(spng1)

            rem_vertices!(ng1, rv)
            rem_vertices!(spng1, rv)

            vertexedge_test(g1, ng1, spng1; edge_equal=true, vertex_equal=true)

            # test that all inactive bits in the graphset are zero
            @test sum(count_ones, ng1.graphset.words; init=0) == sum(ng1.graphset)

            es = edges(g2)
            if !isempty(es)
                edge = last(collect(es))

                rem_edge!(g2, edge)
                vertexedge_test(g2, ng2, spng2; edge_equal=false, vertex_equal=true)

                rem_edge!(ng2, edge)
                rem_edge!(spng2, edge)
                vertexedge_test(g2, ng2, spng2; edge_equal=true, vertex_equal=true)

                # test that all inactive bits in the graphset are zero
                @test sum(count_ones, ng2.graphset.words; init=0) == sum(ng2.graphset)
            end

            add_vertex!(g3)
            vertexedge_test(g3, ng3, spng3; edge_equal=true, vertex_equal=false)

            add_vertex!(spng3)
            add_vertex!(ng3)
            vertexedge_test(g3, ng3, spng3; edge_equal=true, vertex_equal=true)

            add_edge!(g3, 1, nv(g3))
            vertexedge_test(g3, ng3, spng3; edge_equal=false, vertex_equal=true)

            add_edge!(spng3, 1, nv(spng3))
            add_edge!(ng3, 1, nv(ng3))
            vertexedge_test(g3, ng3, spng3; edge_equal=true, vertex_equal=true)

            # test that all inactive bits in the graphset are zero
            @test sum(count_ones, ng3.graphset.words; init=0) == sum(ng3.graphset)

            add_vertices!(g4, 10)
            vertexedge_test(g4, ng4, spng4; edge_equal=true, vertex_equal=false)

            add_vertices!(spng4, 10)
            add_vertices!(ng4, 10)
            vertexedge_test(g4, ng4, spng4; edge_equal=true, vertex_equal=true)

            add_edge!(g4, 1, nv(g4))
            vertexedge_test(g4, ng4, spng4; edge_equal=false, vertex_equal=true)

            add_edge!(spng4, 1, nv(ng4))
            add_edge!(ng4, 1, nv(spng4))
            vertexedge_test(g4, ng4, spng4; edge_equal=true, vertex_equal=true)

            # test that all inactive bits in the graphset are zero
            @test sum(count_ones, ng4.graphset.words; init=0) == sum(ng4.graphset)
        end
    end
end