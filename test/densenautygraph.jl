rng = Random.Random.MersenneTwister(0) # Use MersenneTwister for Julia 1.6 compat
symmetrize_adjmx(A) = (A = convert(typeof(A), (A + A') .> 0); for i in axes(A, 1); end; A)

@testset "densenautygraph" begin
    nverts = [1, 2, 3, 4, 5, 10, 20, 31, 32, 33, 50, 63, 64, 
              65, 100, 122, 123, 124, 125, 126, 200, 500, 1000]
    As = [rand(rng, [0, 1], i, i) for i in nverts]

    wtypes = [UInt16, UInt32, UInt64]

    gs = []
    ngs = []
    for A in As, wt in wtypes
        Asym = symmetrize_adjmx(A)
        push!(gs, Graph(Asym))
        push!(gs, DiGraph(A))
        push!(ngs, NautyGraph{wt}(Asym))
        push!(ngs, NautyDiGraph{wt}(A))
    end

    for (g, ng) in zip(gs, ngs)
        g, ng = copy(g), copy(ng)

        @test adjacency_matrix(g) == adjacency_matrix(ng)
        @test edges(ng) == edges(g)
        @test collect(edges(g)) == collect(edges(ng))
        @test nv(g) == nv(ng)
        @test ne(g) == ne(ng)

        rv = sort(unique(rand(rng, 1:nv(ng), 4)))

        rem_vertices!(g, rv, keep_order=true)
        rem_vertices!(ng, rv)
        @test adjacency_matrix(g) == adjacency_matrix(ng)
        @test nv(g) == nv(ng)
        @test ne(g) == ne(ng)
    end

    for (g, ng) in zip(gs, ngs)
        g, ng = copy(g), copy(ng)

        es = edges(g)
        if !isempty(es)
            edge = last(collect(es))

            rem_edge!(g, edge)
            rem_edge!(ng, edge)
            @test adjacency_matrix(g) == adjacency_matrix(ng)
            @test nv(g) == nv(ng)
            @test ne(g) == ne(ng)
        end
    end

    for (g, ng) in zip(gs, ngs)
        g, ng = copy(g), copy(ng)

        add_vertex!(g)
        add_vertex!(ng)
        add_edge!(g, 1, nv(g))
        add_edge!(ng, 1, nv(ng))
        @test adjacency_matrix(g) == adjacency_matrix(ng)
    end

    for (g, ng) in zip(gs, ngs)
        g, ng = copy(g), copy(ng)

        add_vertices!(g, 500)
        add_vertices!(ng, 500)
        add_edge!(g, 1, 2)
        add_edge!(ng, 1, 2)
        @test adjacency_matrix(g) == adjacency_matrix(ng)
    end

    # LOOPS
    g_loop0 = Graph([1 0 0; 0 1 0; 0 0 0])
    ng_loop0 = NautyGraph([1 0 0; 0 1 0; 0 0 0])

    @test ne(g_loop0) == ne(ng_loop0)

    add_edge!(g_loop0, 1, 2)
    add_edge!(ng_loop0, 1, 2)
    @test ne(ng_loop0) == ne(g_loop0)

    rem_vertex!(g_loop0, 3)
    rem_vertex!(ng_loop0, 3)
    @test ne(ng_loop0) == ne(g_loop0)

    rem_edge!(g_loop0, 1, 2)
    rem_edge!(ng_loop0, 1, 2)
    @test ne(ng_loop0) == ne(g_loop0)

    g_diloop0 = DiGraph([1 0 0; 0 1 0; 0 0 0])
    ng_diloop0 = NautyDiGraph([1 0 0; 0 1 0; 0 0 0])

    @test ne(g_diloop0) == ne(ng_diloop0)

    add_edge!(g_diloop0, 1, 2)
    add_edge!(ng_diloop0, 1, 2)
    @test ne(ng_diloop0) == ne(g_diloop0)

    rem_vertex!(g_diloop0, 3)
    rem_vertex!(ng_diloop0, 3)
    @test ne(ng_diloop0) == ne(g_diloop0)

    rem_edge!(g_diloop0, 1, 2)
    rem_edge!(ng_diloop0, 1, 2)
    @test ne(ng_diloop0) == ne(g_diloop0)

    g_loop = Graph(2)
    ng_loop = NautyGraph(2)

    add_edge!(g_loop, 1, 1)
    add_edge!(ng_loop, 1, 1)
    @test ne(ng_loop) == ne(g_loop)

    @test adjacency_matrix(ng_loop) == adjacency_matrix(g_loop)

    add_edge!(g_loop, 1, 2)
    add_edge!(ng_loop, 1, 2)
    @test ne(ng_loop) == ne(g_loop)

    g_diloop = DiGraph(2)
    ng_diloop = NautyDiGraph(2)
    add_edge!(g_diloop, 1, 1)
    add_edge!(ng_diloop, 1, 1)
    @test ne(ng_diloop) == ne(g_diloop)

    @test adjacency_matrix(ng_diloop) == adjacency_matrix(g_diloop)

    add_edge!(g_diloop, 1, 1)
    @test add_edge!(ng_diloop, 1, 1) == false
    @test ne(ng_diloop) == ne(g_diloop)

    @test adjacency_matrix(ng_diloop) == adjacency_matrix(g_diloop)

    add_edge!(g_diloop, 1, 2)
    add_edge!(ng_diloop, 1, 2)
    @test ne(ng_diloop) == ne(g_diloop)

    empty_g = NautyGraph(0)
    @test nv(empty_g) == 0
    @test ne(empty_g) == 0
    
    g0 = erdos_renyi(70, 100; rng=rng)
    rand_g = NautyGraph(g0)
    rand_g_dir = NautyDiGraph(g0)
    @test rand_g_dir.graphset == rand_g.graphset

    @test nv(rand_g) == 70
    @test ne(rand_g) == 100
    @test vertices(rand_g) == Base.OneTo(70)

    for edge in edges(rand_g)
        @test has_edge(rand_g, edge)
    end
    for edge in edges(g0)
        @test has_edge(rand_g, edge)
    end
    for vertex in vertices(rand_g)
        @test has_vertex(rand_g, vertex)
        @test outdegree(rand_g, vertex) == length(outneighbors(rand_g, vertex))
        @test indegree(rand_g, vertex) == length(inneighbors(rand_g, vertex))
    end

    @test has_edge(rand_g, 1, 71) == false
    @test has_edge(rand_g, 75, 5) == false

    es = [Edge(1, 2), Edge(2, 3), Edge(2, 4)]
    g = NautyDiGraph(4)
    for e in es
        add_edge!(g, e)
    end

    k = NautyDiGraph(es)
    
    @test g == k

    g2 = copy(g)
    g3 = copy(g)

    @test add_edge!(g2, 2, 5) == false
    @test g2 == g3

    @test outneighbors(g, 2) == [3, 4]
    @test outneighbors(g, 1) == [2]

    @test inneighbors(g, 2) == [1]
    @test inneighbors(g, 1) == []

    @test add_edge!(copy(g), 1, 3) == true
    @test add_edge!(copy(g), 1, 2) == false

    @test rem_edge!(copy(g), 1, 3) == false
    @test rem_edge!(copy(g), 1, 2) == true
    @test rem_edge!(copy(g), Edge(1, 2)) == true

    @test add_vertices!(copy(g), 3; vertex_labels=[1, 2, 3]) == 3

    @test rem_vertex!(copy(g), 5) == false

    g4 = copy(g)
    add_vertices!(g4, 5; vertex_labels=1:5)
    @test g4.labels == vcat(g.labels, 1:5)

    g5 = copy(g)
    g5.labels = [1, 4, 5, 10]
    g6 = copy(g5)
    @test labels(g6) == [1, 4, 5, 10]

    rem_vertices!(g6, [1, 3])
    @test labels(g6) == [4, 10]

    h = NautyDiGraph(4)
    copy!(h, g)
    @test h.graphset == g.graphset
    @test h.graphset.n == g.graphset.n
    @test h.ne == g.ne
    @test h.graphset.m == g.graphset.m
    @test h.labels == g.labels
    @test h.iscanon == g.iscanon

    glab = NautyGraph(5; vertex_labels=1:5)
    add_edge!(glab, 1, 2)
    add_edge!(glab, 1, 3)
    add_edge!(glab, 1, 4)
    add_edge!(glab, 1, 5)
    add_edge!(glab, 2, 5)

    gind1 = glab[[1, 5, 2]]
    @test gind1.labels == [1, 5, 2]

    gind2 = glab[[Edge(1, 2), Edge(1, 4)]]
    @test gind2.labels == [1, 2, 4]

    gb = NautyGraph(g0)
    vg = DiGraph(g)

    bb_ng = blockdiag(gb, g)
    bb_g = NautyDiGraph(blockdiag(DiGraph(g0), vg))
    @test bb_ng == bb_g
end