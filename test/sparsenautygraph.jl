@testset "sparsenautygraph" begin
    nverts = [1, 2, 3, 4, 5, 10, 20, 31, 32, 33, 50, 63, 64, 100, 200]
    As = [rand(rng, [zeros(i ÷ 2); 1], i, i) for i in nverts]

    gs = []
    ngs = []
    for A in As
        Asym = symmetrize_adjmx(A)
        push!(gs, Graph(Asym))
        push!(gs, DiGraph(A))
        push!(ngs, SparseNautyGraph{false}(Asym))
        push!(ngs, SparseNautyGraph{true}(A))
    end

    for (g, ng) in zip(gs, ngs)
        g, ng = copy(g), copy(ng)

        @test adjacency_matrix(g) == adjacency_matrix(ng)
        # @test edges(ng) == edges(g)
        # @test collect(edges(g)) == collect(edges(ng))

        rv = sort(unique(rand(rng, 1:nv(ng), 4)))

        rem_vertices!(g, rv, keep_order=true)
        rem_vertices!(ng, rv)
        @test adjacency_matrix(g) == adjacency_matrix(ng)
    end

    # for (g, ng) in zip(gs, ngs)
    #     g, ng = copy(g), copy(ng)

    #     es = edges(g)
    #     if !isempty(es)
    #         edge = last(collect(es))

    #         rem_edge!(g, edge)
    #         rem_edge!(ng, edge)
    #         @test adjacency_matrix(g) == adjacency_matrix(ng)
    #     end
    # end

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
end