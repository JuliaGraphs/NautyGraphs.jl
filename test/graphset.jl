using NautyGraphs: active_words, _maybe_copy_active_words

function test_graphsets(A; mfacts)
    n, _ = size(A)
    for mf in mfacts
        g16 = Graphset{UInt16}(A, mf * cld(n, NautyGraphs.wordsize(UInt16)))
        @test g16 == A
        
        g32 = Graphset{UInt32}(A, mf * cld(n, NautyGraphs.wordsize(UInt32)))
        @test g32 == A
        @test g32 == g16
        @test hash(g32) == hash(g16)

        g64 = Graphset{UInt64}(A, mf * cld(n, NautyGraphs.wordsize(UInt64)))
        @test g64 == A
        @test g64 == g32
        @test hash(g64) == hash(g32)
    end
    return
end

@testset "graphset" begin
    ns = [1, 2, 5, 15, 16, 17, 31, 32, 33, 63, 64, 65, 500]
    As = [rand(rng, Bool, n, n) for n in ns]
    test_graphsets.(As; mfacts=1:3)

    gs1 = Graphset{UInt64}(3, 1)
    @test_throws BoundsError gs1[1, 4]

    gs2 = Graphset{UInt64}(3, 2)
    @test_throws BoundsError gs2[1, 4]

    A = [1 0 0; 1 1 0; 0 0 1]
    gs1 .= A
    gs2 .= A

    @test gs1 == gs2
    @test hash(gs1) == hash(gs2)

    NautyGraphs._rem_vertex!(gs1, 3)
    NautyGraphs._rem_vertex!(gs2, 1)

    @test gs1 != gs2
    @test hash(gs1) != hash(gs2)

    gs3 = copy(gs1)
    gs4 = copy(gs1)

    NautyGraphs.increase_padding!(gs4, 1)

    @test gs3 == gs4
    @test hash(gs3) == hash(gs4)
    @test gs3.words == collect(active_words(gs4))

    NautyGraphs.increase_padding!(gs4, 2)
    NautyGraphs.increase_padding!(gs4, 3)

    @test gs3 == gs4
    @test hash(gs3) == hash(gs4)
    @test collect(active_words(gs3)) == collect(active_words(gs4))
      
    gs5 = Graphset{UInt64}(3, 2)
    gs6 = Graphset{UInt64}(3, 2)

    NautyGraphs._rem_vertex!(gs5, 2)
    NautyGraphs._add_vertex!(gs5)

    @test gs5 == gs6
    @test hash(gs5) == hash(gs6)

    # graphsets of differing order must not compare equal, even when one is a prefix of the other
    @test Graphset{UInt64}(5, 1) != Graphset{UInt64}(10, 1)
    @test Graphset{UInt64}(64, 1) != Graphset{UInt64}(128, 2)

    ### unsorted or repeated indices are rejected before anything is mutated
    gs = Graphset{UInt64}(rand(rng, Bool, 6, 6))
    reference = copy(gs.words)
    for inds in ([3, 1], [2, 2], [1, 3, 2])
        @test_throws ArgumentError NautyGraphs._rem_vertices!(gs, inds)
        @test gs.n == 6
        @test gs.words == reference
    end

    @testset "_maybe_copy_active_words" begin
        for W in (UInt16, UInt32, UInt64), n in [0, 1, 15, 16, 17, 63, 64, 65, 200]
            A = rand(rng, Bool, n, n)
            mmin = cld(n, NautyGraphs.wordsize(W))
            gs = Graphset{W}(A, mmin)

            # without excess padding the words are handed back as they are, without copying
            @test _maybe_copy_active_words(gs) === gs.words

            # with excess padding the padding words are dropped, leaving the same content
            padded = Graphset{W}(A, 3 * mmin)
            @test padded == gs
            words = _maybe_copy_active_words(padded)
            @test length(words) == n * mmin
            @test words == gs.words
            n > 0 && @test words !== padded.words

            # same words, in the same order, as the lazy iterator
            @test words == collect(active_words(padded))
            @test _maybe_copy_active_words(gs) == collect(active_words(gs))
        end

        # padding left behind by vertex removal is dropped too
        gs = Graphset{UInt64}(rand(rng, Bool, 80, 80))
        for _ in 1:70
            NautyGraphs._rem_vertex!(gs, 1)
        end
        @test gs.m > cld(gs.n, NautyGraphs.wordsize(UInt64))
        @test _maybe_copy_active_words(gs) == collect(active_words(gs))
        @test _maybe_copy_active_words(gs) == Graphset{UInt64}(collect(gs)).words
    end
end