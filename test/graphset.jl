using NautyGraphs: active_words

rng = Random.Random.MersenneTwister(0) # Use MersenneTwister for Julia 1.6 compat

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
end