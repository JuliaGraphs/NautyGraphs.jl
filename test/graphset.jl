function test_graphsets(A; mfacts)
    n, _ = size(A)
    for mf in mfacts
        g16 = Graphset{UInt16}(A, mf * cld(n, NautyGraphs.wordsize(UInt16)))
        @test g16 == A
        
        g32 = Graphset{UInt32}(A, mf * cld(n, NautyGraphs.wordsize(UInt32)))
        @test g32 == A

        g64 = Graphset{UInt64}(A, mf * cld(n, NautyGraphs.wordsize(UInt64)))
        @test g64 == A
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

    NautyGraphs._rem_vertex!(gs1, 3)
    NautyGraphs._rem_vertex!(gs2, 1)

    @test gs1 != gs2

    gs4 = Graphset{UInt64}(3, 2)
    gs5 = Graphset{UInt64}(3, 2)

    NautyGraphs._rem_vertex!(gs4, 2)
    NautyGraphs._add_vertex!(gs4)

    @test gs4 == gs5
end