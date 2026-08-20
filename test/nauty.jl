using SHA
using NautyGraphs: NautyOptions, NautyStatistics

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
        @test order(autg) > typemax(Int64)

        verylarge_g = SpNautyGraph(50)
        _, autg = nauty(verylarge_g)
        @test order(autg) > typemax(Int64)

        # Test that canonical_id doesnt error for large graphs
        glarge = NautyGraph(200)
        canonical_id(glarge)
    end

    @testset "options" begin
        # `NautyOptions` and `NautyStatistics` are passed to C, so their layouts have to keep
        # matching nauty's `optionblk` and `statsblk`.
        if Sys.WORD_SIZE == 64
            @test sizeof(NautyOptions) == 128
            @test [fieldoffset(NautyOptions, i) for i in 1:fieldcount(NautyOptions)] ==
                [0, 4, 8, 12, 16, 20, 24, 32, 40, 48, 56, 64, 72, 80, 88, 92, 96, 100, 104, 112, 120]

            @test sizeof(NautyStatistics) == 88
            @test [fieldoffset(NautyStatistics, i) for i in 1:fieldcount(NautyStatistics)] ==
                [0, 8, 12, 16, 20, 24, 32, 40, 48, 56, 64, 72, 80]
        end

        g = NautyGraph(smallgraph(:petersen))

        # Nauty writes into `statsblk`, so `NautyStatistics` has to stay mutable.
        @test ismutabletype(NautyStatistics)
        @test all(f -> getfield(NautyStatistics(), f) == 0, fieldnames(NautyStatistics))
        buffer = NautyBuffer(g)
        NautyGraphs._fillcanon!(buffer, g, NautyOptions(g))
        @test buffer.statistics.errstatus == 0
        @test buffer.statistics.grpsize1 == 120
        @test buffer.statistics.numgenerators > 0

        # Test correct assignment of dispatch vectors
        dispatches = [NautyOptions(NautyGraph{UInt16}(4)).dispatch,
                      NautyOptions(NautyGraph{UInt32}(4)).dispatch,
                      NautyOptions(NautyGraph{UInt64}(4)).dispatch,
                      NautyOptions(SpNautyGraph(4)).dispatch]
        @test all(!=(C_NULL), dispatches)
        @test allunique(dispatches)

        # Keyword constructor
        o = NautyOptions(g)
        @test o.getcanon == 1
        @test o.digraph == 1
        @test o.defaultptn == 0
        @test o.writeautoms == 0  # nauty should not write to stdout on its own
        @test NautyOptions(g; digraph_or_loops=false).digraph == 0
        @test NautyOptions(g; ignorelabels=true).defaultptn == 1

        # Copy constructor
        base = NautyOptions(g)
        @test NautyOptions(base) === base
        @test NautyOptions(base; digraph=false).digraph == 0
        @test NautyOptions(base; digraph=false).dispatch == base.dispatch

        # The callbacks can be switched on and off after the fact
        withgens = NautyOptions(base; generators=true, exact_order=true)
        @test withgens.userautomproc == NautyOptions(g; generators=true).userautomproc
        @test withgens.userlevelproc == NautyOptions(g; exact_order=true).userlevelproc
        @test NautyOptions(withgens; generators=false).userautomproc == C_NULL
        @test NautyOptions(withgens; generators=false).userlevelproc == withgens.userlevelproc
        @test NautyOptions(withgens; exact_order=false).userlevelproc == C_NULL

        # Leaving them out preserves whatever is installed, including a hand-set callback
        @test NautyOptions(withgens; digraph=false).userautomproc == withgens.userautomproc
        @test NautyOptions(withgens; digraph=false).userlevelproc == withgens.userlevelproc
        handset = NautyOptions(base.getcanon, base.digraph, base.writeautoms, base.writemarkers,
                base.defaultptn, base.cartesian, base.linelength, base.outfile, base.userrefproc,
                Ptr{Cvoid}(UInt(0xdeadbeef)), Ptr{Cvoid}(UInt(0xfeedface)), base.usernodeproc,
                base.usercanonproc, base.invarproc, base.tc_level, base.mininvarlevel,
                base.maxinvarlevel, base.invararg, base.dispatch, base.schreier,
                base.extra_options)
        @test NautyOptions(handset; digraph=false).userautomproc == Ptr{Cvoid}(UInt(0xdeadbeef))
        @test NautyOptions(handset; digraph=false).userlevelproc == Ptr{Cvoid}(UInt(0xfeedface))
        @test NautyOptions(handset; generators=false).userautomproc == C_NULL
    end

    @testset "canonical" begin
        for G in (NautyGraph, NautyDiGraph, SpNautyGraph, SpNautyDiGraph)
            g = G(6; vertex_labels=[3, 1, 4, 1, 5, 9])
            add_edge!(g, 1, 2); add_edge!(g, 2, 3); add_edge!(g, 5, 6)
            before = copy(g)

            h, perm = canonical(g)

            # g is left alone, h is the canonized version
            @test g == before
            @test !iscanon(g)
            @test iscanon(h)
            @test h ≃ g
            @test canonical_id(h) == canonical_id(g)
            @test perm == canonical_permutation(g)
            @test labels(h) == labels(g)[perm]
            @test ne(h) == ne(g)
            @test nv(h) == nv(g)

            # matches the in-place route
            k = copy(g)
            permk = canonize!(k)
            @test perm == permk
            @test h == k

            # an already canonical graph gives back an independent copy, not an alias
            h2, perm2 = canonical(h)
            @test h2 == h
            @test perm2 == 1:nv(h)
            @test h2 !== h
            @test labels(h2) !== labels(h)
            if h isa NautyGraphs.DenseNautyGraph
                @test h2.graphset.words !== h.graphset.words
            else
                @test h2.e !== h.e && h2.v !== h.v && h2.d !== h.d
            end

            # empty graphs must work too
            e, ep = canonical(G(0))
            @test nv(e) == 0 && isempty(ep)
        end
    end

    @testset "canonical_id stability" begin
        # `canonical_id` hashes a specific byte layout. Changing that layout silently
        # invalidates every id a user has stored, so pin a few down.
        @test canonical_id(NautyGraph(smallgraph(:petersen))) ==
            41318317913488837734360009271770145373
        @test canonical_id(SpNautyGraph(smallgraph(:petersen))) ==
            173868311105659546303316759195715112189
        @test canonical_id(NautyDiGraph([Edge(1, 2), Edge(2, 3), Edge(3, 4), Edge(4, 5), Edge(5, 1)])) ==
            295248309473264944339498477569561032550

        # hashing must not depend on how the adjacency lists happen to be laid out, nor on
        # whether the graph was canonized in place first
        for G in (NautyGraph, SpNautyGraph)
            g = G(smallgraph(:petersen))
            h, _ = canonical(g)
            k = copy(g); canonize!(k)
            @test canonical_id(g) == canonical_id(h) == canonical_id(k)
        end

        # hashing has to work for every array shape `canonical_id` feeds it
        digest(x) = (ctx = SHA.SHA256_CTX(); NautyGraphs._shaupdate!(ctx, x); SHA.digest!(ctx))
        for x in (Cint[3, 1, 4, 1, 5], collect(1:50), view(collect(1:20), [7, 2, 19, 4]), Cint[])
            @test digest(x) == digest(collect(x))
        end

        # excess padding words must not change the hash of an otherwise equal graph
        a = NautyGraph(erdos_renyi(12, 0.4; seed=1))
        b = NautyGraph(90)
        for _ in 1:(nv(b) - nv(a)); rem_vertex!(b, nv(b)); end
        for e in edges(a); add_edge!(b, src(e), dst(e)); end
        @test b.graphset.m > cld(nv(b), 64)
        @test a == b && canonical_id(a) == canonical_id(b)
    end

    @testset "automorphisms" begin
        # `p` is an automorphism if it is a permutation that preserves both labels and adjacency
        function isautomorphism(g, p)
            length(p) == nv(g) && isperm(p) || return false
            all(label(g, p[i]) == label(g, i) for i in vertices(g)) || return false
            return all(has_edge(g, p[src(e)], p[dst(e)]) for e in edges(g))
        end

        # every element of the group the generators generate, by breadth-first closure
        function closure(gens, n)
            identity = collect(Cint(1):Cint(n))
            elements = Set([identity])
            queue = [identity]
            while !isempty(queue)
                q = pop!(queue)
                for gen in gens
                    r = gen[q]
                    r in elements && continue
                    push!(elements, r)
                    push!(queue, r)
                end
            end
            return elements
        end

        # nothing is collected unless it is asked for
        g = NautyGraph(smallgraph(:petersen))
        _, autg = nauty(g)
        @test isnothing(generators(autg))
        @test order(autg) isa Float64
        @test order(autg) == 120
        @test NautyOptions(g).userautomproc == C_NULL
        @test NautyOptions(g).userlevelproc == C_NULL
        @test NautyOptions(g; generators=true).userautomproc != C_NULL
        @test NautyOptions(g; exact_order=true).userlevelproc != C_NULL

        # the flags are independent
        @test isnothing(generators(nauty(g; exact_order=true)[2]))
        @test order(nauty(g; exact_order=true)[2]) isa BigInt
        @test order(nauty(g; generators=true)[2]) isa Float64

        # generators are automorphisms, and there are as many as nauty reports
        for G in (NautyGraph, NautyDiGraph, SpNautyGraph, SpNautyDiGraph),
            base in (smallgraph(:petersen), complete_graph(5), path_graph(6), cycle_graph(7),
                     erdos_renyi(9, 0.4; seed=3))

            h = G(base)
            _, autg = nauty(h; generators=true, exact_order=true)

            probe = NautyBuffer(h)
            NautyGraphs._fillcanon!(probe, h, NautyOptions(h))
            @test length(generators(autg)) == probe.statistics.numgenerators

            @test all(p -> isautomorphism(h, p), generators(autg))
            @test length(closure(generators(autg), nv(h))) == order(autg)
        end

        # known group orders, exactly
        for (base, truth) in ((smallgraph(:petersen), big(120)), (complete_graph(6), big(720)),
                              (cycle_graph(8), big(16)), (path_graph(5), big(2)),
                              (complete_graph(1), big(1)))
            _, autg = nauty(NautyGraph(base); exact_order=true)
            @test order(autg) == truth
        end

        # the exact order stays exact where the `Float64` cannot
        _, autg = nauty(NautyGraph(50); exact_order=true)
        @test order(autg) == factorial(big(50))
        _, autg = nauty(NautyGraph(200); exact_order=true)
        @test order(autg) == factorial(big(200))
        @test order(nauty(NautyGraph(200))[2]) == Inf

        # labels restrict the group
        labeled = NautyGraph(4; vertex_labels=[1, 1, 2, 2])
        _, autg = nauty(labeled; generators=true, exact_order=true)
        @test order(autg) == 4
        @test all(p -> isautomorphism(labeled, p), generators(autg))

        # empty and single-vertex graphs
        for G in (NautyGraph, SpNautyGraph)
            _, autg = nauty(G(0); generators=true, exact_order=true)
            @test isempty(generators(autg))
            @test order(autg) == 1

            _, autg = nauty(G(1); generators=true, exact_order=true)
            @test isempty(generators(autg))
            @test order(autg) == 1
        end

        # a later run must not disturb the generators handed out by an earlier one
        _, first = nauty(NautyGraph(smallgraph(:petersen)); generators=true)
        kept = deepcopy(generators(first))
        _, second = nauty(NautyGraph(complete_graph(6)); generators=true)
        @test generators(first) == kept
        @test generators(first) !== generators(second)

        # canonizing renumbers the group along with the graph
        k = NautyGraph(smallgraph(:petersen))
        _, plain = nauty(k; generators=true, exact_order=true)
        _, autg = nauty(k; canonize=true, generators=true, exact_order=true)
        @test iscanon(k)
        @test order(autg) == order(plain)
        @test all(p -> isautomorphism(k, p), generators(autg))
        @test length(closure(generators(autg), nv(k))) == order(autg)
        # the orbit structure is the same partition, just renumbered
        @test sort(length.(orbit_partition(autg))) == sort(length.(orbit_partition(plain)))
        @test orbits(autg) == [minimum(o) for v in vertices(k)
                               for o in orbit_partition(autg) if v in o]

        # the same holds for a graph whose orbits are not all singletons or the whole vertex set
        m = NautyGraph(path_graph(5))
        _, mplain = nauty(m; generators=true)
        _, mcanon = nauty(m; canonize=true, generators=true)
        @test all(p -> isautomorphism(m, p), generators(mcanon))
        @test sort(length.(orbit_partition(mcanon))) == sort(length.(orbit_partition(mplain)))

        # orbits are one-based and label each vertex with the smallest vertex it maps to
        _, autg = nauty(NautyGraph(path_graph(5)))
        @test orbits(autg) == Cint[1, 2, 3, 2, 1]
        @test orbit_partition(autg) == [[1, 5], [2, 4], [3]]
        @test all(v -> orbits(autg)[v] in vertices(NautyGraph(path_graph(5))), 1:5)

        # a graph with no symmetry has one orbit per vertex
        rigid = NautyGraph(erdos_renyi(12, 0.5; seed=11))
        _, autg = nauty(rigid; generators=true)
        @test order(autg) == 1
        @test orbits(autg) == Cint.(1:12)
        @test orbit_partition(autg) == [[v] for v in 1:12]

        # the trivial group is generated by the empty set, not by the identity: the identity is a
        # member of every automorphism group and is never listed as a generator
        @test isempty(generators(autg))
        @test closure(generators(autg), nv(rigid)) == Set([collect(Cint(1):Cint(nv(rigid)))])
        @test length(closure(generators(autg), nv(rigid))) == order(autg)

        # printing
        limited(x) = sprint((io, y) -> show(IOContext(io, :limit => true), y), x)
        plain(x) = sprint((io, y) -> show(IOContext(io, :limit => true), MIME"text/plain"(), y), x)

        petersen = automorphism_group(NautyGraph(smallgraph(:petersen)))
        @test limited(petersen) == "AutomorphismGroup(order=120, vertices=10, orbits=1, generators=4)"
        @test plain(petersen) == """
            AutomorphismGroup
              order       120
              vertices    10
              orbits      1
              generators  4"""

        # a group whose generators were never asked for says so instead of showing zero
        nogens = nauty(NautyGraph(path_graph(5)))[2]
        @test limited(nogens) == "AutomorphismGroup(order=2.0, vertices=5, orbits=3)"
        @test occursin("generators  not computed", plain(nogens))

        # an order of hundreds of digits is abbreviated only when the output is limited
        huge = automorphism_group(NautyGraph(200))
        @test occursin("(375 digits)", limited(huge))
        @test occursin("vertices=200, orbits=1, generators=199", limited(huge))
        @test occursin(string(factorial(big(200))), sprint(show, huge))

        # keywords other than `canonize` reach `NautyOptions`
        labeled2 = NautyGraph(4; vertex_labels=[1, 1, 2, 2])
        @test order(nauty(labeled2)[2]) == 4
        @test order(nauty(labeled2; ignorelabels=true)[2]) == 24
        @test order(nauty(labeled2; ignorelabels=true, exact_order=true)[2]) == big(24)
        @test nauty(labeled2; digraph_or_loops=false) isa Tuple
        @test_throws MethodError nauty(labeled2; nosuchoption=true)

        # `automorphism_group` gives everything and leaves the graph alone
        for G in (NautyGraph, NautyDiGraph, SpNautyGraph, SpNautyDiGraph)
            base = G(smallgraph(:petersen))
            snapshot = copy(base)
            autg = automorphism_group(base)

            @test base == snapshot
            @test !iscanon(base)
            @test order(autg) isa BigInt
            @test order(autg) == 120
            @test !isnothing(generators(autg))
            @test all(p -> isautomorphism(base, p), generators(autg))
            @test length(closure(generators(autg), nv(base))) == order(autg)
            @test orbit_partition(autg) == [collect(1:10)]

            # it agrees with the `nauty` call it stands for
            _, viaanauty = nauty(base; generators=true, exact_order=true)
            @test order(autg) == order(viaanauty)
            @test orbits(autg) == orbits(viaanauty)
        end

        # labelled and asymmetric graphs go through the same path
        labeled3 = NautyGraph(6; vertex_labels=[1, 1, 1, 2, 2, 2])
        add_edge!(labeled3, 1, 4); add_edge!(labeled3, 2, 5); add_edge!(labeled3, 3, 6)
        autg = automorphism_group(labeled3)
        @test order(autg) == 6
        @test all(p -> isautomorphism(labeled3, p), generators(autg))
        @test length(closure(generators(autg), nv(labeled3))) == order(autg)

        autg = automorphism_group(NautyGraph(erdos_renyi(12, 0.5; seed=11)))
        @test order(autg) == 1
        @test isempty(generators(autg))

        # passing options explicitly requests whatever they were built with
        _, autg = nauty(g, NautyOptions(g; generators=true))
        @test length(generators(autg)) == 4
        _, autg = nauty(g, NautyOptions(g; exact_order=true))
        @test order(autg) == big(120)

        # the buffer is task-local
        buffers = fetch.([Threads.@spawn objectid(NautyGraphs.automorphism_buffer()) for _ in 1:4])
        @test length(unique(buffers)) == 4

        results = fetch.([Threads.@spawn begin
            h = NautyGraph(smallgraph(:petersen))
            _, a = nauty(h; generators=true, exact_order=true)
            (order(a), length(generators(a)), all(p -> isautomorphism(h, p), generators(a)))
        end for _ in 1:8])
        @test all(==((big(120), 4, true)), results)

        # a callback failure surfaces as an error rather than being swallowed
        NautyGraphs.automorphism_buffer().errorcode = NautyGraphs._OUT_OF_MEMORY
        @test_throws OutOfMemoryError NautyGraphs._check_automorphism_buffer()
        NautyGraphs._reset_automorphism_buffer!()
        @test NautyGraphs._check_automorphism_buffer() === nothing

        # a callback must record a failure rather than throw, because throwing would unwind through
        # nauty's C frames. A negative length fails the allocation the way running out of memory
        # would, without needing the pointer arguments to be valid.
        @test NautyGraphs._record_generator(Cint(0), Ptr{Cint}(C_NULL), Ptr{Cint}(C_NULL),
                Cint(0), Cint(0), Cint(-1)) === nothing
        @test NautyGraphs.automorphism_buffer().errorcode == NautyGraphs._OUT_OF_MEMORY
        @test isempty(NautyGraphs.automorphism_buffer().generators)
        @test_throws OutOfMemoryError NautyGraphs._check_automorphism_buffer()
        NautyGraphs._reset_automorphism_buffer!()

        # options that contradict the graph, or that switch the canonical form off, are rejected
        directed = NautyDiGraph([Edge(1, 2), Edge(2, 3)])
        @test_throws ArgumentError nauty(directed; digraph_or_loops=false)
        @test_throws ArgumentError nauty(directed, NautyOptions(directed; digraph_or_loops=false))
        @test_throws ArgumentError nauty(g, NautyOptions(NautyOptions(g); getcanon=0))
    end

    @testset "buffer" begin
        # a reused buffer has to give exactly what a fresh one does, even though nauty finds it
        # full of the previous run's data
        for G in (NautyGraph, NautyDiGraph, SpNautyGraph, SpNautyDiGraph)
            shared = NautyBuffer(G(1))
            for n in (0, 1, 7, 33, 64, 65, 40, 5), p in (0.0, 0.35, 1.0)
                g = G(erdos_renyi(n, p; seed=n + 1))
                @test canonical_id(g; buffer=shared) == canonical_id(g)
                @test canonical_permutation(g; buffer=shared) == canonical_permutation(g)

                inplace, fresh = copy(g), copy(g)
                @test canonize!(inplace; buffer=shared) == canonize!(fresh)
                @test inplace == fresh
            end
        end

        # labels that give a non-trivial colouring exercise `ptn`, whose last entry used to be left
        # untouched by the in-place fill and so held stale data in a reused buffer
        shared = NautyBuffer(NautyGraph(1))
        for labelling in ([1, 1, 2, 2, 3], [1, 2, 3, 4, 5], [7, 7, 7, 7, 7], [2, 1, 2, 1, 2])
            g = NautyGraph(path_graph(5))
            setlabels!(g, labelling)
            @test canonical_id(g; buffer=shared) == canonical_id(g)
        end

        # a buffer grows and shrinks with the graph, leaving nothing of the previous run behind
        big = NautyGraph(erdos_renyi(80, 0.3; seed=4))
        small = NautyGraph(erdos_renyi(6, 0.5; seed=5))
        shared = NautyBuffer(big)
        canonical_id(big; buffer=shared)
        @test canonical_id(small; buffer=shared) == canonical_id(small)
        @test canonical_id(big; buffer=shared) == canonical_id(big)

        # `nauty` and `automorphism_group` take a buffer too
        g = NautyGraph(smallgraph(:petersen))
        shared = NautyBuffer(g)
        @test nauty(g; buffer=shared)[1] == nauty(g)[1]
        p1, a1 = nauty(g; generators=true, exact_order=true, buffer=shared)
        p2, a2 = nauty(g; generators=true, exact_order=true)
        @test p1 == p2 && order(a1) == order(a2) && orbits(a1) == orbits(a2)
        @test generators(a1) == generators(a2)
        @test order(automorphism_group(g; buffer=shared)) == order(a2)

        # what `nauty` hands back is copied out of the buffer, so a later run must not disturb it
        keptperm, keptorbits = copy(p1), copy(orbits(a1))
        canonical_id(NautyGraph(complete_graph(9)); buffer=shared)
        @test p1 == keptperm
        @test orbits(a1) == keptorbits

        # comparing two graphs needs two buffers, because both canonical forms have to be alive
        h = NautyGraph(smallgraph(:petersen))
        @test is_isomorphic(g, h; buffers=(NautyBuffer(g), NautyBuffer(h)))
        @test_throws ArgumentError is_isomorphic(g, h; buffers=(shared, shared))
        k = NautyGraph(complete_graph(10))
        @test !is_isomorphic(g, k; buffers=(NautyBuffer(g), NautyBuffer(k)))

        # vertices are `Int` wherever they reach the caller
        @test eltype(canonical_permutation(g)) === Int
        @test eltype(canonize!(copy(g))) === Int
        @test eltype(canonical(g)[2]) === Int
        autg = automorphism_group(g)
        @test eltype(orbits(autg)) === Int
        @test all(p -> eltype(p) === Int, generators(autg))
        @test eltype(orbit_partition(autg)[1]) === Int
    end

    @testset "statistics" begin
        g = NautyGraph(smallgraph(:petersen))

        # Reusing a buffer's statistics is only safe because nauty sets every field of `statsblk`
        # on every run.
        clean = NautyBuffer(g)
        NautyGraphs._fillcanon!(clean, g)
        dirty = NautyBuffer(g)
        dirty.statistics = NautyStatistics(-99.0, -99, -99, -99, -99, 99, 99, -99, 99, 99, 99, 99, -99)
        NautyGraphs._fillcanon!(dirty, g)
        @test all(f -> getfield(dirty.statistics, f) == getfield(clean.statistics, f),
                  fieldnames(NautyStatistics))

        # reuse across two different graphs must not leak either
        reused = NautyBuffer(g)
        NautyGraphs._fillcanon!(reused, NautyGraph(complete_graph(7)))
        NautyGraphs._fillcanon!(reused, g)
        @test all(f -> getfield(reused.statistics, f) == getfield(clean.statistics, f),
                  fieldnames(NautyStatistics))
    end
end

