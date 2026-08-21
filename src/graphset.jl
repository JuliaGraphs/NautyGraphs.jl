"""
    Graphset{W}

A graphset is a special bit matrix used to represent the adjacency matrix 
of a nauty graph in dense format. For a graph on `n` vertices, the graphset
contains `n*m` "words", i.e. unsigned integers that contain the bits of 
the adjacency matrix, where `m` is the number of words per vertex.

The organization of words is as follows:
```
   ------------ m words per vertex ----->  
   | 0x00000000, 0x00000000, 0x00000000, ...  
 n | 0x00000000, 0x00000000, 0x00000000, ...  
   | 0x00000000, 0x00000000, 0x00000000, ...  
   v
```
"""
mutable struct Graphset{W<:Unsigned} <: AbstractMatrix{Bool}
    words::Vector{W}
    n::Int
    m::Int

    function Graphset{W}(n::Integer, m=cld(n, wordsize(W))) where {W}
        if n > m * wordsize(W)
            throw(ArgumentError("Not enough words to hold n=$n vertices. Increase m or use a larger word type."))
        end
        words = zeros(W, n*m)
        return new{W}(words, n, m)
    end
end
function Graphset{W}(A::AbstractMatrix, m=cld(size(A,1), wordsize(W))) where {W}
    n1, n2 = size(A)
    n1 == n2 || throw(ArgumentError("Adjacency / distance matrices must be square"))
    gset = Graphset{W}(n1, m)
    gset .= A
    return gset
end
Graphset(args...) = Graphset{UInt}(args...)

Base.size(gset::Graphset) = (gset.n, gset.n)
Base.IndexStyle(::Type{Graphset}) = IndexCartesian()
Base.similar(gset::Graphset{W}) where {W} = Graphset{W}(gset.n, gset.m)

Base.hash(gset::Graphset, h::UInt) = _graphsethash(gset, h)
@generated function _graphsethash(gset::Graphset{W}, h::UInt) where {W}
    return quote hashlong = @ccall $(libnauty(W)).hashgraph(
        gset.words::Ref{W},
        gset.m::Cint,
        gset.n::Cint,
        reinterpret(Clong, h)::Clong)::Clong 
        return reinterpret(UInt, hashlong)
    end
end

Base.sum(g::Graphset{W}; kwargs...) where {W} = g.n > 0 ? sum(count_ones, active_words(g); kwargs...) : zero(W)

# Return the active words as a contiguous vector, row by row.
# `gset.words` itself is returned when there is no excess padding, so the result aliases `gset`
# unless padding had to be dropped, and must not be mutated.
@inline function _maybe_copy_active_words(gset::Graphset{W}) where {W}
    m = cld(gset.n, wordsize(W))
    m == gset.m && return gset.words
    words = Vector{W}(undef, gset.n * m)
    for i in Base.OneTo(gset.n)
        copyto!(words, (i - 1) * m + 1, gset.words, (i - 1) * gset.m + 1, m)
    end
    return words
end

@inline function active_words(gset::Graphset{W}) where {W}
    # Return the words actually used for representing the matrix, without any unnecessary padding
    m_eff = cld(gset.n, wordsize(W))
    return (gset.words[(i - 1) * gset.m + j] for i in 1:gset.n for j in 1:m_eff)
end
# if both graphsets have the same word type, we can directly compare words; otherwise, we fall back to elementwise compare
# `zip` stops at the shorter side, so graphsets of differing order have to be rejected up front
Base.:(==)(gs1::Graphset{W}, gs2::Graphset{W}) where {W} =
    gs1.n == gs2.n && all(w1 == w2 for (w1, w2) in zip(active_words(gs1), active_words(gs2)))

function Base.copy!(dest::Graphset, src::Graphset)
    dest.n = src.n
    dest.m = src.m
    copy!(dest.words, src.words)
    return dest
end
function Base.copy(gset::Graphset)
    out = similar(gset)
    copyto!(out.words, gset.words)
    return out
end

@inline wordtype(::Graphset{W}) where {W} = W
@inline wordsize(u::Unsigned) = 8 * sizeof(u)
@inline wordsize(T::Type{<:Unsigned}) = 8 * sizeof(T)
@inline wordsize(::Graphset{W}) where {W} = wordsize(W)
@inline logwordsize(::Type{UInt8}) = 3
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

function increase_padding!(gset::Graphset{W}, Δm::Integer=1) where {W}
    Δm > 0 || return gset

    oldm = gset.m
    gset.m += Δm
    resize!(gset.words, gset.n * gset.m)

    # Spreading the rows apart in place has to run back to front, so that a row is only ever moved
    # into space its successor has already vacated.
    for i in gset.n:-1:1
        copyto!(gset.words, (i - 1) * gset.m + 1, gset.words, (i - 1) * oldm + 1, oldm)
        fill!(view(gset.words, ((i - 1) * gset.m + oldm + 1):(i * gset.m)), zero(W))
    end
    return gset
end
# function decrease_padding!(gset::Graphset{W}, Δm::Integer=1) where {W}
#     return gset
# end
# function minimize_padding!(gset::Graphset{W}) where {W}
# end

# Bit ranges within a row of `m` words are addressed by a zero-based position counted from the most
# significant bit of the row's first word, which is the order `bitaddress` lays a vertex out in.
@inline _topmask(::Type{W}, len::Integer) where {W} = typemax(W) << (wordsize(W) - len)

# Read the `len <= wordsize(W)` bits at `pos`, returned aligned to the top of a word.
@inline function _readbits(words::Vector{W}, base::Integer, pos::Integer, len::Integer) where {W}
    ws = wordsize(W)
    idx = base + divlogpow2(logwordsize(W), pos) + 1
    offset = pos & (ws - 1)
    bits = words[idx] << offset
    if offset + len > ws
        bits |= words[idx + 1] >> (ws - offset)
    end
    return bits & _topmask(W, len)
end

# Write the top `len <= wordsize(W)` bits of `bits` at `pos`, leaving the surrounding bits alone.
@inline function _writebits!(words::Vector{W}, base::Integer, pos::Integer, len::Integer, bits::W) where {W}
    ws = wordsize(W)
    idx = base + divlogpow2(logwordsize(W), pos) + 1
    offset = pos & (ws - 1)
    mask = _topmask(W, len) >> offset
    words[idx] = (words[idx] & ~mask) | ((bits >> offset) & mask)
    if offset + len > ws
        tailmask = _topmask(W, offset + len - ws)
        words[idx + 1] = (words[idx + 1] & ~tailmask) | ((bits << (ws - offset)) & tailmask)
    end
    return
end

# Move `len` bits of a row from `from` to the earlier position `to`. Each chunk is read before it is
# written, so the two ranges may overlap.
@inline function _movebits!(words::Vector{W}, base::Integer, from::Integer, to::Integer, len::Integer) where {W}
    from == to && return
    ws = wordsize(W)
    while len > 0
        chunk = min(len, ws)
        _writebits!(words, base, to, chunk, _readbits(words, base, from, chunk))
        from += chunk
        to += chunk
        len -= chunk
    end
    return
end

function _add_vertices!(gset::Graphset{W}, n::Integer) where {W} # TODO think of a better name
    increase_padding!(gset, cld(gset.n + n, wordsize(gset)) - gset.m)
    oldlength = length(gset.words)
    resize!(gset.words, oldlength + n * gset.m)
    fill!(view(gset.words, (oldlength + 1):length(gset.words)), zero(W))
    gset.n += n
    return gset
end
_add_vertex!(gset::Graphset) = _add_vertices!(gset, 1)

function _rem_vertices!(gset::Graphset{W}, inds) where {W}
    nrv = length(inds)
    # checked before anything is mutated, so that bad indices cannot leave a half-shifted graphset
    issorted(inds, lt=<=) || throw(ArgumentError("indices must be unique and sorted"))

    nold = gset.n
    deleteat!(gset.words, Iterators.flatten(1+(i-1)*gset.m:i*gset.m for i in inds))
    gset.n -= nrv

    n, m, ws = gset.n, gset.m, wordsize(W)
    for i in Base.OneTo(n)
        # The surviving columns form runs between the removed ones. Moving each run straight to where
        # it belongs costs one pass over the row, where shifting once per removed column costs `nrv`.
        base = (i - 1) * m
        written = 0
        previous = 0
        for ind in inds
            runlength = ind - previous - 1
            if runlength > 0
                _movebits!(gset.words, base, previous, written, runlength)
                written += runlength
            end
            previous = ind
        end
        _movebits!(gset.words, base, previous, written, nold - previous)

        # the columns the runs vacated have to read as zero, so that padding never reaches nauty
        stale = m * ws - n
        position = n
        while stale > 0
            chunk = min(stale, ws)
            _writebits!(gset.words, base, position, chunk, zero(W))
            position += chunk
            stale -= chunk
        end
    end
    return gset
end
_rem_vertex!(gset::Graphset, i::Integer) = _rem_vertices!(gset, (i,))