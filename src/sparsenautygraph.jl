mutable struct SparseNautyGraph{D} <: AbstractNautyGraph{Int}
    nv::Int             # number of vertices
    nde::Int            # number of directed edges
    v::Vector{Csize_t}  # edgelist positions of vertices (zero-based)
    d::Vector{Cint}     # vertex degrees
    e::Vector{Cint}     # edgelist (zero-based)
    labels::Vector{Int} # vertex labels
end

"""
    SparseNautyGraph{D}(n::Integer; [vertex_labels, ne=n]) where {D}

Construct a `SparseNautyGraph` on `n` vertices and 0 edges. 
Can be directed (`D = true`) or undirected (`D = false`).
Vertex labels can optionally be specified. If `ne` is provided, enough 
memory for `ne` optimally packed edges is allocated.
"""
function SparseNautyGraph{D}(n::Integer; vertex_labels=nothing, ne=n) where {D}
    if !isnothing(vertex_labels) && n != length(vertex_labels)
        throw(ArgumentError("The number of vertices is not compatible with the length of `vertex_labels`."))
    end
    v = zeros(n)
    d = zeros(Cint, n)
    e = -ones(Cint, ne) # encode unused values as -1
    if isnothing(vertex_labels)
        vertex_labels = zeros(Int, n)
    end
    return SparseNautyGraph{D}(n, 0, v, d, e, vertex_labels)
end

"""
    SparseNautyGraph{D}(A::AbstractMatrix; [vertex_labels]) where {D}

Construct a `SparseNautyGraph{D}` from the adjacency matrix `A`.
If `A[i][j] != 0`, an edge `(i, j)` is inserted. `A` must be a square matrix.
The graph can be directed (`D = true`) or undirected (`D = false`). If `D = false`, `A` must be symmetric.
Vertex labels can optionally be specified.
"""
function SparseNautyGraph{D}(A::AbstractMatrix; vertex_labels=nothing) where {D}
    n, m = size(A)
    isequal(n, m) || throw(ArgumentError("Adjacency / distance matrices must be square"))
    D || issymmetric(A) || throw(ArgumentError("Adjacency / distance matrices must be symmetric"))

    g = SparseNautyGraph{D}(n; vertex_labels, ne=sum(isone, A))
    for i in axes(A, 1), j in axes(A, 2)
        A[i, j] != 0 && _add_directed_edge!(g, i, j)
    end
    return g
end

"""
    SparseNautyGraph{D}(edge_list::Vector{<:AbstractEdge}; [vertex_labels]) where {D}

Construct a `SparseNautyGraph` from a vector of edges.
The number of vertices is the highest that is used in an edge in `edge_list`.
The graph can be directed (`D = true`) or undirected (`D = false`).
Vertex labels can optionally be specified.
To achieve optimal memory efficiency, it is recommended to sort the edge list beforehand.
"""
function SparseNautyGraph{D}(edge_list::Vector{<:AbstractEdge}; vertex_labels=nothing) where {D}
    nvg = 0
    for e in edge_list
        nvg = max(nvg, src(e), dst(e))
    end

    # sort edgelist to optimize neighborlist packing
    # edge_list = sort(edge_list)

    g = SparseNautyGraph{D}(nvg; vertex_labels, ne=length(edge_list))
    for edge in edge_list
        add_edge!(g, edge)
    end
    trim_edgelist!(g)
    return g
end

function (::Type{G})(g::AbstractGraph) where {G<:SparseNautyGraph}
    ng = g isa AbstractNautyGraph ? G(nv(g); vertex_labels=labels(g), ne=ne(g)) : G(nv(g); ne=ne(g))
    for v in vertices(g)
        for n in neighbors(g, v)
            _add_directed_edge!(ng, v, n)
        end
    end
    return ng
end

libnauty(::SparseNautyGraph) = nauty_jll.libnautyTL
libnauty(::Type{<:SparseNautyGraph}) = nauty_jll.libnautyTL

# C-compatible representation of a sparsenautygraph
mutable struct SparseGraphRep
    nde::Csize_t
    v::Ptr{Csize_t}
    nv::Cint
    d::Ptr{Cint}
    e::Ptr{Cint}
    w::Ptr{Cint}
    vlen::Csize_t
    dlen::Csize_t
    elen::Csize_t
    wlen::Csize_t
end
function SparseGraphRep()
    return SparseGraphRep(0, C_NULL, 0, C_NULL, C_NULL, C_NULL, 0, 0, 0, 0)
end

function Base.cconvert(::Type{Ref{SparseGraphRep}}, sref::Ref{<:SparseNautyGraph})
    s = sref[]
    cstr = SparseGraphRep(s.nde, pointer(s.v), s.nv, pointer(s.d), pointer(s.e), C_NULL, length(s.v), length(s.d), length(s.e), 0)
    return (s, cstr)
end
function Base.unsafe_convert(::Type{Ref{SparseGraphRep}}, x::Tuple{<:SparseNautyGraph,SparseGraphRep})
    _, cstr = x
    return convert(Ptr{SparseGraphRep}, pointer_from_objref(cstr))
end

@generated function sortlists!(g::SparseNautyGraph)
    # Sort the lists in the graph rep into some reference order
    return quote
        @ccall $(libnauty(g)).sortlists_sg(Ref(g)::Ref{SparseGraphRep})::Cvoid
    end
end

Base.copy(g::G) where {G<:SparseNautyGraph} = G(g.nv, g.nde, copy(g.v), copy(g.d), copy(g.e), copy(g.labels))
function Base.copy!(dest::G, src::G) where {G<:SparseNautyGraph}
    copy!(dest.v, src.v)
    copy!(dest.d, src.d)
    copy!(dest.e, src.e)
    copy!(dest.labels, src.labels)

    dest.ne = src.ne
    dest.nde = src.nde
    return dest
end

Base.show(io::Core.IO, g::SparseNautyGraph{false}) = print(io, "{$(nv(g)), $(ne(g))} undirected SparseNautyGraph")
Base.show(io::Core.IO, g::SparseNautyGraph{true}) = print(io, "{$(nv(g)), $(ne(g))} directed SparseNautyGraph")

function Base.hash(g::SparseNautyGraph, h::UInt)
    return hash(g.labels, hash(vertices(g), hash(edges(g), h)))
end

@generated function Base.:(==)(g::SparseNautyGraph{D1}, h::SparseNautyGraph{D2}) where {D1, D2}
    return quote D1 == D2 && 
    labels(g) == labels(h) && 
    Bool(@ccall $(libnauty(g)).aresame_sg(Ref(g)::Ref{SparseGraphRep}, Ref(h)::Ref{SparseGraphRep})::Cint)
    end
end

Graphs.nv(g::SparseNautyGraph) = g.nv
function Graphs.ne(g::SparseNautyGraph)
    if nv(g) == 0
        return 0
    elseif is_directed(g)
        return g.nde
    else
        return (g.nde + sum(has_edge(g, i, i) for i in vertices(g))) ÷ 2
    end
end
Graphs.vertices(g::SparseNautyGraph) = Base.OneTo(g.nv)
Graphs.has_vertex(g::SparseNautyGraph, v::Integer) = v ∈ vertices(g)
function Graphs.has_edge(g::SparseNautyGraph, s::Integer, d::Integer)
    (has_vertex(g, s) && has_vertex(g, d)) || return false
    for i in outneighbors(g, s)
        i == d && return true
    end
    return false
end

@inline function Graphs.outdegree(g::SparseNautyGraph, v::Integer)
    # following the Graph.jl implementation, there is no boundscheck here
    return g.d[v]
end
@inline function fadj(g::SparseNautyGraph, v::Integer)
    return @view g.e[(1 + g.v[v]):(g.v[v] + g.d[v])]
end
@inline function Graphs.outneighbors(g::SparseNautyGraph, v::Integer)
    # following the Graph.jl implementation, there is no boundscheck here
    return (1 + g.e[i] for i in (1 + g.v[v]):(g.v[v] + g.d[v]))
end
@inline function Graphs.indegree(g::SparseNautyGraph, v::Integer)
    # following the Graph.jl implementation, there is no boundscheck here
    return is_directed(g) ? sum(has_edge(g, i, v) for i in vertices(g)) : outdegree(g, v)
end
@inline function Graphs.inneighbors(g::SparseNautyGraph, v::Integer)
    # following the Graph.jl implementation, there is no boundscheck here
    return is_directed(g) ? (i for i in vertices(g) if has_edge(g, i, v)) : outneighbors(g, v)
end

function Graphs.edges(g::SparseNautyGraph)
    return SimpleEdgeIter(g)
end
eltype(::Type{SimpleEdgeIter{<:SparseNautyGraph}}) = Graphs.SimpleGraphEdge{Int}
function Base.iterate(eit::SimpleEdgeIter{G}) where {G<:SparseNautyGraph}
    sortlists!(eit.g)
    return Base.iterate(eit, (1, 1))
end
function Base.iterate(eit::SimpleEdgeIter{G}, state) where {G<:SparseNautyGraph}
    g = eit.g
    n = nv(g)
    i, nidx = state

    while nidx > g.d[i]
        i += 1
        nidx = 1
        i > n && return nothing
    end

    w = 1 + g.e[g.v[i] + nidx]

    if !is_directed(g) && w < i && has_edge(g, i, w)
        return Base.iterate(eit, (i, nidx + 1))
    else
        return Graphs.SimpleEdge{Int}(i, w), (i, nidx + 1)
    end
end
function Base.:(==)(e1::SimpleEdgeIter{<:SparseNautyGraph}, e2::SimpleEdgeIter{<:SparseNautyGraph})
    g = e1.g
    h = e2.g
    sortlists!(g)
    sortlists!(h)
    
    ne(g) == ne(h) || return false
    m = min(nv(g), nv(h))

    for i in 1:m
        fadj(g, i) == fadj(h, i) || return false
    end
    nv(g) == nv(h) && return true
    for i in (m + 1):nv(g)
        isempty(fadj(g, i)) || return false
    end
    for i in (m + 1):nv(h)
        isempty(fadj(h, i)) || return false
    end
    return true
end
function Base.:(==)(e1::SimpleEdgeIter{<:SparseNautyGraph}, e2::SimpleEdgeIter{<:Graphs.SimpleGraphs.AbstractSimpleGraph})
    g = e1.g
    h = e2.g
    sortlists!(g)

    ne(g) == ne(h) || return false
    is_directed(g) == is_directed(h) || return false

    m = min(nv(g), nv(h))
    
    for i in 1:m
        neighs_g = NautyGraphs.fadj(g, i)
        neighs_h = Graphs.SimpleGraphs.fadj(h, i)
        length(neighs_g) == length(neighs_h) || return false
        all(ngh -> 1 + ngh[1] == ngh[2], zip(neighs_g, neighs_h)) || return false
    end

    nv(g) == nv(h) && return true
    for i in (m + 1):nv(g)
        isempty(NautyGraphs.fadj(g, i)) || return false
    end
    for i in (m + 1):nv(h)
        isempty(Graphs.SimpleGraphs.fadj(h, i)) || return false
    end
    return true
end
Base.:(==)(e1::SimpleEdgeIter{<:Graphs.SimpleGraphs.AbstractSimpleGraph}, e2::SimpleEdgeIter{<:SparseNautyGraph}) = e2 == e1

Graphs.is_directed(::SparseNautyGraph{D}) where {D} = D
Graphs.is_directed(::Type{SparseNautyGraph{D}}) where {D} = D

function trim_edgelist!(g::SparseNautyGraph)
    excess_length = 0

    for i in Iterators.Reverse(g.e)
        i != NONEIGHBOR && break
        excess_length += 1
    end
    resize!(g.e, length(g.e) - excess_length)
    return excess_length
end

const NONEIGHBOR = -1

function Graphs.add_edge!(g::SparseNautyGraph, e::Edge)
    has_vertex(g, e.src) && has_vertex(g, e.dst) || return false
    has_edge(g, e.src, e.dst) && return false # TODO this checks has_vertex again

    _add_directed_edge!(g, e.src, e.dst)
    if !is_directed(g) && e.src != e.dst
        _add_directed_edge!(g, e.dst, e.src)
    end
    return true
end
function _add_directed_edge!(g::SparseNautyGraph, i::Integer, j::Integer)
    idx = Int(1 + g.v[i] + g.d[i])

    # If this is the first edge of vertex i
    # find a free spot to start its neighborlist
    if isone(idx)
        idx = findfirst(==(NONEIGHBOR), g.e)
        # If there is no free spot, we will append at the end
        if isnothing(idx)
            idx = length(g.e) + 1
        end
        g.v[i] = idx - 1
    end

    # If there is a free spot at the end of the list, append j
    if idx in eachindex(g.e) && g.e[idx] == NONEIGHBOR
        g.e[idx] = j - 1
    # otherwise insert j and shift the other indices
    else
        insert!(g.e, idx, j - 1)
        @views @. g.v[1:end != i] = ifelse(g.v[1:end != i] >= idx-1, g.v[1:end != i]+1, g.v[1:end != i])
    end
    g.d[i] += 1
    g.nde += 1
    return true
end
function Graphs.rem_edge!(g::SparseNautyGraph, e::Edge)
    has_vertex(g, e.src) && has_vertex(g, e.dst) || return false
    has_edge(g, e.src, e.dst) || return false # TODO this checks has_vertex again

    _rem_directed_edge!(g, e.src, e.dst)
    if !is_directed(g) && e.src != e.dst
        _rem_directed_edge!(g, e.dst, e.src)
    end
    return true
end
function _rem_directed_edge!(g::SparseNautyGraph, i::Integer, j::Integer)
    v, d = 1 + g.v[i], g.d[i]
    idx = findfirst(==(j - 1), @view g.e[v:v+d-1])
    isnothing(idx) && return false

    vrem = v + idx - 1
    vlast = v + d - 1

    if idx == d
        g.e[vrem] = NONEIGHBOR
    else
        # Swap with the last edge and remove
        elast = g.e[vlast]
        g.e[vrem] = elast
        g.e[vlast] = NONEIGHBOR
    end
    g.d[i] -= 1
    g.nde -= 1
    return true
end

function Graphs.add_vertices!(g::SparseNautyGraph, n::Integer; vertex_labels=0)
    vertex_labels isa Number || n != length(vertex_labels) && throw(ArgumentError("Incompatible length: trying to add `n=$n` vertices, but`vertex_labels` has length $(length(vertex_labels))."))

    nold = g.nv
    nnew = nold + n
    resize!(g.v, nnew)
    resize!(g.d, nnew)
    resize!(g.labels, nnew)

    g.v[nold+1:end] .= 0
    g.d[nold+1:end] .= 0
    g.labels[nold+1:end] .= vertex_labels

    g.nv = nnew
    return true
end
Graphs.add_vertex!(g::SparseNautyGraph; vertex_label::Integer=0) = Graphs.add_vertices!(g, 1; vertex_labels=vertex_label) > 0

function Graphs.rem_vertices!(g::SparseNautyGraph, inds)
    isempty(inds) && return true
    all(i->has_vertex(g, i), inds) || return false

    for i in vertices(g)
        if i in inds
            vstart, d = 1 + g.v[i], g.d[i]
            d == 0 && continue

            vend = vstart + d - 1
            # Free memory for outneighbors
            deleteat!(g.e, vstart:vend)
            # TODO: this redundantly shifts indices that will be deleted below
            @. g.v = ifelse(g.v > vend - 1, g.v - d, g.v)
        else
            # Keep memory for inneighbors
            for j in inds
                _rem_directed_edge!(g, i, j)
            end
        end
    end
    deleteat!(g.v, inds)
    deleteat!(g.d, inds)
    deleteat!(g.labels, inds)

    # shift vertices in edge list
    for i in eachindex(g.e)
        g.e[i] -= sum(<(1 + g.e[i]), inds)
    end

    g.nv = length(g.v)
    g.nde = sum(!=(NONEIGHBOR), g.e; init=0)
    return true
end
Graphs.rem_vertex!(g::SparseNautyGraph, i::Integer) = rem_vertices!(g, (i,))


function _unsafe_copyfromsparsegraphrep!(g::SparseNautyGraph, srep::SparseGraphRep)
    copy!(g.e, unsafe_wrap(Array, srep.e, srep.elen))
    copy!(g.v, unsafe_wrap(Array, srep.v, srep.vlen))
    copy!(g.d, unsafe_wrap(Array, srep.d, srep.dlen))
    return
end
function _free_sparsegraphrep(srep::SparseGraphRep)
    _sparsenautyfree(srep.e)
    _sparsenautyfree(srep.v)
    _sparsenautyfree(srep.d)
    return
end
@generated function _sparsenautyfree(arr::Ptr{T}) where {T}
    return quote
        @ccall $(libnauty(SparseNautyGraph)).free(arr::Ptr{T})::Cvoid
    end
end