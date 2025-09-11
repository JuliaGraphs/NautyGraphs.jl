using NautyGraphs: _ghash_base64, _ghash_SHA64, _ghash_SHA128, _ghash_xxhash64, _ghash_xxhash128, increase_padding!

@testset "hashing" begin
    l1 = collect(1:20)
    g = Graphset{UInt}(20)
    g[1, 2] = g[2, 1] = g[19, 14] = g[13, 7] = g[5, 5] = g[1, 20] = 1

    h = copy(g)
    l2 = copy(l1)

    @test _ghash_base64(g, l1) == _ghash_base64(h, l2)
    @test _ghash_xxhash64(g, l1) == _ghash_xxhash64(h, l2)
    @test _ghash_xxhash128(g, l1) == _ghash_xxhash128(h, l2)
    @test _ghash_SHA64(g, l1) == _ghash_SHA64(h, l2)
    @test _ghash_SHA128(g, l1) == _ghash_SHA128(h, l2)

    k = copy(g)
    increase_padding!(k, 1)

    @test _ghash_base64(g, l1) == _ghash_base64(k, l2)
    @test _ghash_xxhash64(g, l1) == _ghash_xxhash64(k, l2)
    @test _ghash_xxhash128(g, l1) == _ghash_xxhash128(k, l2)
    @test _ghash_SHA64(g, l1) == _ghash_SHA64(k, l2)
    @test _ghash_SHA128(g, l1) == _ghash_SHA128(k, l2)


    g = NautyDiGraph(8; vertex_labels=[1, 1, 2, 3, 4, 5, 5, 5])
    add_edge!(g, 1, 2)
    add_edge!(g, 4, 1)
    add_edge!(g, 2, 8)
    add_edge!(g, 3, 8)
    add_edge!(g, 8, 3)

    h = copy(g)[[1, 4, 3, 2, 5, 6, 8, 7]]

    @test ghash(g; alg=XXHash64Alg()) == ghash(h; alg=XXHash64Alg())
    @test ghash(g; alg=XXHash128Alg()) == ghash(h; alg=XXHash128Alg())
    @test ghash(g; alg=SHA64Alg()) == ghash(h; alg=SHA64Alg())
    @test ghash(g; alg=SHA128Alg()) == ghash(h; alg=SHA128Alg())
    @test ghash(g; alg=Base64Alg()) == ghash(h; alg=Base64Alg())
end