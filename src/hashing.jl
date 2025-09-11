abstract type AbstractHashAlg end
struct Base64Alg <: AbstractHashAlg end
struct XXHash64Alg <: AbstractHashAlg end
struct XXHash128Alg <: AbstractHashAlg end
struct SHA64Alg <: AbstractHashAlg end
struct SHA128Alg <: AbstractHashAlg end

function _ghash_base64(gset::Graphset, labels)
    if length(gset) > 8192
        throw(ArgumentError("Graph is too large (`nv(g) > 90`) and cannot be hashed using `Base64Alg`. Use a different hash algorithm instead."))
    end
    return Base.hash(labels, Base.hash(collect(active_words(gset))))
end

__xxhash64(x::AbstractArray) = @ccall xxHash_jll.libxxhash.XXH3_64bits(Ref(x, 1)::Ptr{Cvoid}, sizeof(x)::Csize_t)::UInt64
__xxhash64seed(x::AbstractArray, seed::UInt64) = @ccall xxHash_jll.libxxhash.XXH3_64bits_withSeed(Ref(x, 1)::Ptr{Cvoid}, sizeof(x)::Csize_t, seed::UInt64)::UInt64
function _ghash_xxhash64(gset::Graphset, labels)
    return __xxhash64seed(labels, __xxhash64(collect(active_words(gset))))
end

__xxhash128(x::AbstractArray) = @ccall xxHash_jll.libxxhash.XXH3_128bits(Ref(x, 1)::Ptr{Cvoid}, sizeof(x)::Csize_t)::UInt128
__xxhash128seed(x::AbstractArray, seed::UInt128) = @ccall xxHash_jll.libxxhash.XXH3_128bits_withSeed(Ref(x, 1)::Ptr{Cvoid}, sizeof(x)::Csize_t, seed::UInt128)::UInt128
function _ghash_xxhash128(gset::Graphset, labels)
    return __xxhash128seed(labels, __xxhash128(collect(active_words(gset))))
end

# as suggested by stevengj here: https://discourse.julialang.org/t/hash-collision-with-small-vectors/131702/10
function __SHAhash(x)
    io = IOBuffer()
    Serialization.serialize(io, x)
    return SHA.sha256(take!(io))
end
__SHAhash64(x) = reinterpret(UInt64, __SHAhash(x))[1]
function _ghash_SHA64(gset::Graphset, labels)
    return __SHAhash64((labels, collect(active_words(gset))))
end
__SHAhash128(x) = reinterpret(UInt128, __SHAhash(x))[1]
function _ghash_SHA128(gset::Graphset, labels)
    return __SHAhash128((labels, collect(active_words(gset))))
end

function _ghash(gset, labels; alg::AbstractHashAlg)
    if alg isa XXHash64Alg
        # We need to allocate any views before we pass them to xxHash
        if labels isa SubArray
            h = _ghash_xxhash64(gset, collect(labels))
        else
            h = _ghash_xxhash64(gset, labels)
        end
    elseif alg isa XXHash128Alg
        if labels isa SubArray
            h = _ghash_xxhash128(gset, collect(labels))
        else
            h = _ghash_xxhash128(gset, labels)
        end
    elseif alg isa SHA64Alg
        h = _ghash_SHA64(gset, labels)
    elseif alg isa SHA128Alg
        h = _ghash_SHA128(gset, labels)
    elseif alg isa Base64Alg
        h = _ghash_base64(gset, labels)
    else
        throw(ArgumentError("$alg is not a valid hashing algorithm."))
    end
    return h
end