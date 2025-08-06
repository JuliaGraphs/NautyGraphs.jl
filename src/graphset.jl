"""
    Graphset{W}

A graphset is a special bit matrix used to represent the adjacency matrix 
of a nauty graph in dense format.

The organization of words is as follows:

   ------------ m words per vertex ----->  
   | 0x00000000, 0x00000000, 0x00000000, ...  
 n | 0x00000000, 0x00000000, 0x00000000, ...  
   | 0x00000000, 0x00000000, 0x00000000, ...  
   v  
"""
mutable struct Graphset{W<:Unsigned} <: AbstractMatrix{Bool}
    words::Vector{W}
    n::Int
    m::Int

    function Graphset{W}(n, m=cld(n, wordsize(W))) where {W}
        if n > m * wordsize(W)
            throw(ArgumentError("Not enough words to hold n=$n vertices. Increase m or use a larger word type."))
        end
        words = zeros(W, n*m)
        return new{W}(words, n, m)
    end
end
Graphset(args...) = Graphset{UInt64}(args...)

Base.size(gset::Graphset) = (gset.n, gset.n)
Base.IndexStyle(::Type{Graphset}) = IndexCartesian()
Base.similar(gset::Graphset{W}) where {W} = Graphset{W}(gset.n, gset.m)

function Base.copy!(dest::Graphset{W}, src::Graphset{W}) where {W}
    dest.n == src.n || throw(ArgumentError("graphsets must have the same size for copy!"))
    if dest.m == src.m
        copyto!(dest.words, src.words)
    else
        dest .== src
    end
    return dest
end

@inline wordtype(::Graphset{W}) where {W} = W
@inline wordsize(u::Unsigned) = 8 * sizeof(u)
@inline wordsize(T::Type{<:Unsigned}) = 8 * sizeof(T)
@inline wordsize(::Graphset{W}) where {W} = wordsize(W)
@inline logwordsize(::Type{UInt16}) = 4
@inline logwordsize(::Type{UInt32}) = 5
@inline logwordsize(::Type{UInt64}) = 6
@inline logwordsize(::Type{UInt128}) = 7
@inline logwordsize(::Graphset{W}) where {W} = logwordsize(W)

@inline mod1pow2(p2, x) = 1 + (x - 1) & (p2 - 1)
@inline divlogpow2(lp2, x) = x >> lp2

@inline function bitaddress(gset::Graphset, i, j)
    ws = wordsize(gset)
    lws = logwordsize(gset)
    wordidx = (i - 1) * gset.m + 1 + divlogpow2(lws, (j - 1))
    bitidx = mod1pow2(ws, j)
    return wordidx, bitidx
end

@inline function getbit(word::W, i::Integer) where {W<:Unsigned}
    ws = wordsize(W)
    @boundscheck checkindex(Bool, Base.OneTo(ws), i) || throw(BoundsError(word, i))
    mask = one(W) << (ws - i)
    return (mask & word) != zero(W)
end

@inline function setbit(word::W, x::Bool, i::Integer) where {W<:Unsigned}
    ws = wordsize(W)
    @boundscheck checkindex(Bool, Base.OneTo(ws), i) || throw(BoundsError(word, i))
    mask = one(W) << (ws - i)
    return ifelse(x, word | mask, word & ~mask)
end

@inline function Base.getindex(gset::Graphset, inds::Vararg{Int,2})
    i, j = inds
    @boundscheck checkbounds(gset, i, j)
    wordidx, bitidx = bitaddress(gset, i, j)
    word = gset.words[wordidx]
    return getbit(word, bitidx)
end

@inline function Base.setindex!(gset::Graphset, x, inds::Vararg{Int,2})
    i, j = inds
    @boundscheck checkbounds(gset, i, j)
    wordidx, bitidx = bitaddress(gset, i, j)
    gset.words[wordidx] = setbit(gset.words[wordidx], convert(Bool, x), bitidx)
    return gset
end

function _increase_padding!(gset::Graphset{W}, m::Integer=1) where {W}
    # TODO: optimize this
    for _ in Base.OneTo(m)
        gset.m += 1
        for i in Base.OneTo(gset.n)
            insert!(gset.words, i * gset.m, zero(W))
        end
    end
    return gset
end

@inline function partial_leftshift(word::Unsigned, n::Integer, start::Integer, fillword::Unsigned=zero(word))
    # Starting from the `start`th bit from the left of `word`, shift all bits to the left `n` times,
    # refill right-most bits with bits from `fillword`. The `n` bits to the left of `start` are
    # overwritten.

    # Select all to-be-moved bits
    mask = typemax(word) >> (start - 1)

    unshifted_part = word & (~mask << n)
    shifted_part = (word & mask) << n
    filled_part = fillword >> (wordsize(typeof(word)) - n)

    return unshifted_part | shifted_part | filled_part
end

function _add_vertices!(gset::Graphset{W}, n::Integer) where {W} # TODO think of a better name
    _increase_padding!(gset, cld(gset.n + n, wordsize(gset)) - gset.m)
    append!(gset.words, fill(zero(W), n*gset.m))
    gset.n += n
    return gset
end
_add_vertex!(gset::Graphset) = _add_vertices!(gset, 1)

function _rem_vertices!(gset::Graphset{W}, inds) where {W}
    nrv = length(inds)

    deleteat!(gset.words, Iterators.flatten(1+(i-1)*gset.m:i*gset.m for i in inds))
    gset.n -= nrv

    wordblock = reshape(gset.words, gset.m, gset.n)'

    δ = 0
    lastind = 0
    for ind in inds
        ind < lastind && throw(ArgumentError("indices must be unique and sorted"))

        wordidx, bitidx = bitaddress(gset, 1, ind - δ)
        for i in axes(wordblock, 1)
            fillword = wordidx == size(wordblock, 2) ? zero(W) : wordblock[i, wordidx+1]
            wordblock[i, wordidx] = partial_leftshift(wordblock[i, wordidx], 1, bitidx+1, fillword)

            for j in wordidx+1:size(wordblock, 2)
                fillword = j == size(wordblock, 2) ? zero(W) : wordblock[i, j+1]
                wordblock[i, j] = partial_leftshift(wordblock[i, j], 1, 1, fillword)
            end
        end
        δ += 1
    end
    return gset
end
_rem_vertex!(gset::Graphset, i::Integer) = _rem_vertices!(gset, (i,))