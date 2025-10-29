# Quick and dirty hash function for testing
function SHAhash(x)
    io = IOBuffer()
    Serialization.serialize(io, x)
    return SHA.sha256(take!(io))
end
SHAhash64(x) = reinterpret(UInt64, SHAhash(x))[1]
SHAhash64(x, h::UInt) = SHAhash64((x, h)) # don't do this at home

@testset "hashing" begin
    g = Graphset{UInt}(20)
    g[1, 2] = g[2, 1] = g[19, 14] = g[13, 7] = g[5, 5] = g[1, 20] = 1

    h = copy(g)
    
    @test _sethash_dense(g) == _sethash_dense(h)
    @test _sethash_dense(Base.hash, g) == _sethash_dense(Base.hash, h)
    @test _sethash_dense(SHAhash64, g) == _sethash_dense(SHAhash64, h)
    
    k = copy(g)
    increase_padding!(k, 1)

    @test _sethash_dense(g) == _sethash_dense(k)
    @test _sethash_dense(Base.hash, g) == _sethash_dense(Base.hash, k)
    @test _sethash_dense(SHAhash64, g) == _sethash_dense(SHAhash64, k)

    g = NautyDiGraph(8; vertex_labels=[1, 1, 2, 3, 4, 5, 5, 5])
    add_edge!(g, 1, 2)
    add_edge!(g, 4, 1)
    add_edge!(g, 2, 8)
    add_edge!(g, 3, 8)
    add_edge!(g, 8, 3)

    h = copy(g)[[1, 4, 3, 2, 5, 6, 8, 7]]
    
    k = NautyDiGraph(8; vertex_labels=[1, 2, 2, 6, 4, 4, 5, 5])
    add_edge!(g, 1, 5)
    add_edge!(g, 4, 2)
    add_edge!(g, 3, 6)
    add_edge!(g, 1, 8)
    add_edge!(g, 8, 3)

    @test ghash(g) != ghash(k)
    @test ghash(Base.hash, g) != ghash(Base.hash, k)
    @test ghash(SHAhash64, g) != ghash(SHAhash64, k)
end