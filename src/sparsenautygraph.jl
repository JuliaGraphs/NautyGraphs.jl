"""
    SparseNautyGraph{D}

Sparse graph format compatible with nauty. Can be directed (`D = true`) or undirected (`D = false`).
This graph format stores the adjacency matrix as an edgelist. Repeated modifications to the graph
may result in suboptimal memory usage.
"""
mutable struct SparseNautyGraph{D} <: AbstractNautyGraph{Int}
    nv::Int              # number of vertices
    nde::Int             # number of directed edges
    v::Vector{Csize_t}   # positions of vertices in edgelist (zero-based)
    d::Vector{Cint}      # vertex degrees
    e::Vector{Cint}      # edgelist (zero-based)
    _labels::Vector{Int} # vertex labels
    iscanon::Bool
    _freeslot::Int       # no slot of `e` before this one is free; see `_add_directed_edge!`
end

"""
    SpNautyGraph

Sparse undirected graph format compatible with nauty, which represents the graph via an edgelist. 
Repeated modifications to a `SpNautyGraph` may result in suboptimal memory usage.
Alias for `SparseNautyGraph{false}`.

See also [`NautyGraph`](@ref), [`NautyDiGraph`](@ref), and [`SpNautyDiGraph`](@ref) for other nauty-compatible graph formats.

"""
const SpNautyGraph = SparseNautyGraph{false}

"""
    SpNautyDiGraph

Sparse directed graph format compatible with nauty, which represents the graph via an edgelist. 
Repeated modifications to a `SpNautyGraph` may result in suboptimal memory usage.
Alias for `SparseNautyGraph{true}`.

See also [`NautyGraph`](@ref), [`NautyDiGraph`](@ref), and [`SpNautyGraph`](@ref) for other nauty-compatible graph formats.
"""
const SpNautyDiGraph = SparseNautyGraph{true}

const NONEIGHBOR = -1

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
    v = zeros(Csize_t, n)
    d = zeros(Cint, n)
    e = NONEIGHBOR * ones(Cint, ne) # encode unused values as NONEIGHBOR (== -1)
    if isnothing(vertex_labels)
        vertex_labels = zeros(Int, n)
    else
        vertex_labels = copy(vertex_labels)
    end
    return SparseNautyGraph{D}(n, 0, v, d, e, vertex_labels, false, 1)
end

"""
    SparseNautyGraph{D}(; vertex_labels) where {D}

Construct a vertex-labeled `SparseNautyGraph` on `length(vertex_labels)` vertices and 0 edges.
Can be directed (`D = true`) or undirected (`D = false`).
"""
function SparseNautyGraph{D}(; vertex_labels) where {D}
    return SparseNautyGraph{D}(length(vertex_labels); vertex_labels)
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

    # every nonzero entry becomes one directed edge, so this is exactly the number of slots needed
    g = SparseNautyGraph{D}(n; vertex_labels, ne=count(!iszero, A))
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

    g = SparseNautyGraph{D}(nvg; vertex_labels, ne=0)
    return _fill_from_edges!(g, edge_list)
end

# Lay out the neighborlists of an edgeless `g` in a single pass. Adding the edges one at a time
# instead makes each edge that lands in an already-occupied slot shift the whole edgelist, which is
# what an unsorted edge list does to every reverse edge of an undirected graph.
function _fill_from_edges!(g::SparseNautyGraph{D}, edge_list) where {D}
    # sorting puts each vertex's neighbors next to each other, and duplicate edges next to each other
    stored = Vector{Tuple{Int,Int}}(undef, 0)
    sizehint!(stored, D ? length(edge_list) : 2 * length(edge_list))
    for edge in edge_list
        s, d = Int(src(edge)), Int(dst(edge))
        (has_vertex(g, s) && has_vertex(g, d)) || continue
        push!(stored, (s, d))
        (D || s == d) || push!(stored, (d, s))
    end
    sort!(stored)

    resize!(g.e, length(stored))
    written = 0
    for (k, (s, d)) in enumerate(stored)
        k > 1 && stored[k - 1] == (s, d) && continue
        written += 1
        g.e[written] = one2zero(d)
        iszero(g.d[s]) && (g.v[s] = written - 1)
        g.d[s] += 1
    end

    resize!(g.e, written)
    g.nde = written
    g._freeslot = written + 1
    return g
end

function SparseNautyGraph{D}(g::AbstractGraph; vertex_labels=nothing) where {D}
    # only a directed graph copied into a directed one stores each edge once; every other combination
    # walks `all_neighbors` and needs up to two slots per edge, which `trim_edgelist!` trims back
    nedges = is_directed(g) && D ? ne(g) : 2ne(g)

    ng = if g isa AbstractNautyGraph
            SparseNautyGraph{D}(nv(g); vertex_labels=isnothing(vertex_labels) ? labels(g) : vertex_labels, ne=nedges)
        else
            SparseNautyGraph{D}(nv(g); vertex_labels, ne=nedges)
    end

    for v in vertices(g)
        neighs = is_directed(g) && is_directed(ng) ? outneighbors : all_neighbors
        for n in neighs(g, v)
            _add_directed_edge!(ng, v, n)
        end
    end
    trim_edgelist!(ng)
    return ng
end
SparseNautyGraph(g::AbstractGraph; vertex_labels=nothing) = SparseNautyGraph{is_directed(g)}(g; vertex_labels)

function Base.copy(g::G) where {G<:SparseNautyGraph}
    return G(g.nv, g.nde, copy(g.v), copy(g.d), copy(g.e), copy(g._labels), g.iscanon, g._freeslot)
end
function Base.copy!(dest::G, src::G) where {G<:SparseNautyGraph}
    copy!(dest.v, src.v)
    copy!(dest.d, src.d)
    copy!(dest.e, src.e)
    copy!(dest._labels, src._labels)

    dest.nv = src.nv
    dest.nde = src.nde
    dest.iscanon = src.iscanon
    dest._freeslot = src._freeslot
    return dest
end

Base.show(io::Core.IO, g::SparseNautyGraph{false}) = print(io, "{$(nv(g)), $(ne(g))} undirected SparseNautyGraph")
Base.show(io::Core.IO, g::SparseNautyGraph{true}) = print(io, "{$(nv(g)), $(ne(g))} directed SparseNautyGraph")

function Base.hash(g::SparseNautyGraph, h::UInt)
    return hash(labels(g), hash(vertices(g), hash(edges(g), h)))
end

libnauty(::SparseNautyGraph) = nauty_jll.libnautyTL
libnauty(::Type{<:SparseNautyGraph}) = nauty_jll.libnautyTL

@inline one2zero(x) = x - one(x)
@inline zero2one(x) = x + one(x)

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

libnauty(::SparseGraphRep) = nauty_jll.libnautyTL
libnauty(::Type{SparseGraphRep}) = nauty_jll.libnautyTL

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
    # Sort the lists in the graph rep into reference order, as defined by nauty
    return quote
        @ccall $(libnauty(g)).sortlists_sg(Ref(g)::Ref{SparseGraphRep})::Cvoid
    end
end
@generated function sortlists!(g::SparseGraphRep)
    # Sort the lists in the graph rep into reference order, as defined by nauty
    return quote
        @ccall $(libnauty(g)).sortlists_sg(Ref(g)::Ref{SparseGraphRep})::Cvoid
    end
end

function _unsafe_copyfromsparsegraphrep!(g::SparseNautyGraph, srep::SparseGraphRep)
    copy!(g.e, unsafe_wrap(Array, srep.e, srep.elen))
    copy!(g.v, unsafe_wrap(Array, srep.v, srep.vlen))
    copy!(g.d, unsafe_wrap(Array, srep.d, srep.dlen))
    # nauty's layout is its own, so the hint has to start over
    g._freeslot = 1
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

@generated function Base.:(==)(g::SparseNautyGraph{D1}, h::SparseNautyGraph{D2}) where {D1, D2}
    return quote D1 == D2 && 
    labels(g) == labels(h) && 
    Bool(@ccall $(libnauty(g)).aresame_sg(Ref(g)::Ref{SparseGraphRep}, Ref(h)::Ref{SparseGraphRep})::Cint)
    end
end

@generated function Base.:(==)(g::SparseGraphRep, h::SparseGraphRep)
    return quote 
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
@inline function _fadj_0based(g::SparseNautyGraph, v::Integer)
    # return the adjacency of vertex `v` as a view into the edge list
    # the resulting indices are zero-based
    return @view g.e[(zero2one(g.v[v])):(g.v[v] + g.d[v])]
end
@inline function _fadj_0based(g::SparseGraphRep, v::Integer)
    # return the adjacency of vertex `v` as an array over nauty's edge list
    # the resulting indices are zero-based
    offset, degree = _adjacencybounds(g, v)
    return unsafe_wrap(Array, g.e + offset * sizeof(Cint), degree)
end

# Where vertex `v`'s neighbours sit in the edge list, as a zero-based offset and a length (degree).
@inline _adjacencybounds(g::SparseGraphRep, v::Integer) = (unsafe_load(g.v, v), unsafe_load(g.d, v))
@inline _adjacencybounds(g::SparseNautyGraph, v::Integer) = (g.v[v], g.d[v])

# The whole edge list as one array.
@inline _edgelist(g::SparseNautyGraph) = g.e
@inline function _edgelist(g::SparseGraphRep)
    # nauty leaves the pointer null for a graph with no edges, which must not be wrapped
    return iszero(g.nde) ? Cint[] : unsafe_wrap(Array, g.e, g.nde)
end

@inline _adjacencyview(edgelist, offset, degree) = @view edgelist[(offset + 1):(offset + degree)]

# Iterate the adjacency of every vertex of `g` in order, as zero-based views into its edge list.
# Unlike calling `_fadj_0based` per vertex, this wraps nauty's edge array only once, which matters
# for callers that walk the whole graph.
@inline function _fadjs_0based(g)
    edgelist = _edgelist(g)
    return (_adjacencyview(edgelist, _adjacencybounds(g, v)...) for v in Base.OneTo(Int(g.nv)))
end
@inline function Graphs.outneighbors(g::SparseNautyGraph, v::Integer)
    # following the Graph.jl implementation, there is no boundscheck here
    return (zero2one(g.e[i]) for i in (zero2one(g.v[v])):(g.v[v] + g.d[v]))
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
Base.eltype(::Type{<:SimpleEdgeIter{<:SparseNautyGraph{false}}}) = Graphs.SimpleGraphEdge{Int}
Base.eltype(::Type{<:SimpleEdgeIter{<:SparseNautyGraph{true}}}) = Graphs.SimpleDiGraphEdge{Int}
function Base.iterate(eit::SimpleEdgeIter{<:SparseNautyGraph})
    sortlists!(eit.g)
    return Base.iterate(eit, (1, 1))
end
function Base.iterate(eit::SimpleEdgeIter{<:SparseNautyGraph}, state)
    g = eit.g
    n = nv(g)
    n == 0 && return nothing

    i, nidx = state

    while nidx > g.d[i]
        i += 1
        nidx = 1
        i > n && return nothing
    end

    w = zero2one(g.e[g.v[i] + nidx])

    # `w` came out of `i`'s own neighborlist, so an undirected graph has already emitted `(w, i)`
    if !is_directed(g) && w < i
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
        _fadj_0based(g, i) == _fadj_0based(h, i) || return false
    end
    nv(g) == nv(h) && return true
    for i in (m + 1):nv(g)
        isempty(_fadj_0based(g, i)) || return false
    end
    for i in (m + 1):nv(h)
        isempty(_fadj_0based(h, i)) || return false
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
        neighs_g = _fadj_0based(g, i)
        neighs_h = Graphs.SimpleGraphs.fadj(h, i)
        length(neighs_g) == length(neighs_h) || return false
        all(ngh -> zero2one(ngh[1]) == ngh[2], zip(neighs_g, neighs_h)) || return false
    end

    nv(g) == nv(h) && return true
    for i in (m + 1):nv(g)
        isempty(_fadj_0based(g, i)) || return false
    end
    for i in (m + 1):nv(h)
        isempty(Graphs.SimpleGraphs.fadj(h, i)) || return false
    end
    return true
end
Base.:(==)(e1::SimpleEdgeIter{<:Graphs.SimpleGraphs.AbstractSimpleGraph}, e2::SimpleEdgeIter{<:SparseNautyGraph}) = e2 == e1
function Base.:(==)(e1::SimpleEdgeIter{<:DenseNautyGraph}, e2::SimpleEdgeIter{<:SparseNautyGraph})
    g = e1.g
    h = e2.g
    ne(g) == ne(h) || return false
    is_directed(g) == is_directed(h) || return false

    m = min(nv(g), nv(h))
    for i in 1:m
        neighs_g = outneighbors(g, i)
        neighs_h = _fadj_0based(h, i)
        length(neighs_g) == length(neighs_h) || return false
        all(ngh -> ngh[1] == zero2one(ngh[2]), zip(neighs_g, neighs_h)) || return false
    end
    nv(g) == nv(h) && return true

    all(iszero, @view g.graphset[m+1:end, :]) || return false
    is_directed(g) || all(iszero, @view g.graphset[1:m, m+1:end]) || return false

    for i in (m + 1):nv(h)
        isempty(_fadj_0based(h, i)) || return false
    end
    return true
end
Base.:(==)(e1::SimpleEdgeIter{<:SparseNautyGraph}, e2::SimpleEdgeIter{<:DenseNautyGraph}) = e2 == e1
function Base.hash(edgeiter::SimpleEdgeIter{<:SparseNautyGraph}, h::UInt=zero(UInt))
    for edge in edgeiter
        h = hash(edge, h)
    end
    return h
end

Graphs.is_directed(::SparseNautyGraph{D}) where {D} = D
Graphs.is_directed(::Type{SparseNautyGraph{D}}) where {D} = D

function trim_edgelist!(g::SparseNautyGraph)
    excess_length = 0

    for i in Iterators.Reverse(g.e)
        i != NONEIGHBOR && break
        excess_length += 1
    end
    resize!(g.e, length(g.e) - excess_length)
    g._freeslot = min(g._freeslot, length(g.e) + 1)
    return excess_length
end

function Graphs.add_edge!(g::SparseNautyGraph, e::Edge)
    has_vertex(g, e.src) && has_vertex(g, e.dst) || return false
    has_edge(g, e.src, e.dst) && return false # TODO this checks has_vertex again

    _add_directed_edge!(g, e.src, e.dst)
    if !is_directed(g) && e.src != e.dst
        _add_directed_edge!(g, e.dst, e.src)
    end
    g.iscanon = false
    return true
end
function _add_directed_edge!(g::SparseNautyGraph, i::Integer, j::Integer)
    idx = Int(zero2one(g.v[i] + g.d[i]))
    isfree = idx in eachindex(g.e) && g.e[idx] == NONEIGHBOR

    # A vertex without neighbors has no list to extend, so it needs a free spot to start one. Until
    # then `g.v[i]` may point anywhere (`blockdiag` leaves it offset), so the degree rather than the
    # position is what decides.
    if iszero(g.d[i]) && !isfree
        # `_freeslot` is a lower bound on the position of the first free spot, which keeps building a
        # graph edge by edge linear rather than rescanning the whole edgelist for every new vertex
        freeidx = findnext(==(NONEIGHBOR), g.e, min(g._freeslot, length(g.e) + 1))
        # If there is no free spot, we will append at the end
        idx = isnothing(freeidx) ? length(g.e) + 1 : freeidx
        g.v[i] = one2zero(idx)
        isfree = !isnothing(freeidx)
        g._freeslot = idx + 1
    end

    # If there is a free spot at the end of the list, append j
    if isfree
        g.e[idx] = one2zero(j)
    # otherwise insert j and shift the other indices
    else
        insert!(g.e, idx, one2zero(j))
        for k in eachindex(g.v)
            k == i && continue
            g.v[k] = ifelse(g.v[k] >= one2zero(idx), g.v[k] + 1, g.v[k])
        end
        # @views @. g.v[1:end != i] = ifelse(g.v[1:end != i] >= one2zero(idx), zero2one(g.v[1:end != i]), g.v[1:end != i])
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
    g.iscanon = false
    return true
end
function _rem_directed_edge!(g::SparseNautyGraph, i::Integer, j::Integer)
    v, d = zero2one(g.v[i]), g.d[i]
    idx = findfirst(==(one2zero(j)), @view g.e[v:v+d-1])
    isnothing(idx) && return false

    vrem = one2zero(v + idx)
    vlast = one2zero(v + d)

    if idx == d
        g.e[vrem] = NONEIGHBOR
        g._freeslot = min(g._freeslot, vrem)
    else
        # Swap with the last edge and remove
        elast = g.e[vlast]
        g.e[vrem] = elast
        g.e[vlast] = NONEIGHBOR
        g._freeslot = min(g._freeslot, vlast)
    end
    g.d[i] -= 1
    g.nde -= 1
    g.iscanon = false
    return true
end

function Graphs.add_vertices!(g::SparseNautyGraph, n::Integer; vertex_labels=0)
    vertex_labels isa Number || n != length(vertex_labels) && throw(ArgumentError("Incompatible length: trying to add `n=$n` vertices, but`vertex_labels` has length $(length(vertex_labels))."))

    nold = g.nv
    nnew = nold + n
    resize!(g.v, nnew)
    resize!(g.d, nnew)
    resize!(g._labels, nnew)

    g.v[nold+1:end] .= 0
    g.d[nold+1:end] .= 0
    g._labels[nold+1:end] .= vertex_labels

    g.nv = nnew
    g.iscanon = false
    return n
end
Graphs.add_vertex!(g::SparseNautyGraph; vertex_label::Integer=0) = Graphs.add_vertices!(g, 1; vertex_labels=vertex_label) > 0
Graphs.add_vertices!(g::SparseNautyGraph; vertex_labels=0) = Graphs.add_vertices!(g, length(vertex_labels); vertex_labels)

"""
    rem_vertices!(g::SparseNautyGraph, inds; compactify=false, buffer=Vector{Cint}(undef, nv(g)))

Remove the vertices `inds` from `g`, which must be given in increasing order.
Return `false` without modifying `g` if any of `inds` is not a vertex of `g`.

Whatever the removal frees is left in the edgelist as free space, which later insertions reuse.
Pass `compactify=true` to gather the surviving neighborlists into a fresh, compacted edgelist instead, which
allocates a new list but lays the neighborlists out in vertex order.

Renumbering the remaining vertices needs one scratch entry per vertex, which `buffer` supplies and
which is grown to fit if it is too short. Hoist it out of a loop that shrinks a graph repeatedly:

```julia
buffer = Vector{Cint}(undef, nv(g))
for inds in batches
    rem_vertices!(g, inds; buffer)
end
```
"""
function Graphs.rem_vertices!(g::SparseNautyGraph, inds; compactify=false, buffer=Vector{Cint}(undef, nv(g)))
    isempty(inds) && return true
    all(i->has_vertex(g, i), inds) || return false
    # checked before anything is mutated, so that bad indices cannot leave a half-deleted graph
    issorted(inds, lt=<=) || throw(ArgumentError("indices must be unique and sorted"))

    # `remap[v]` is the new index of old vertex `v`, or zero if `v` is being removed. Renumbering is
    # what needs this: a neighborlist is in no particular order, so the shift of each entry has to be
    # looked up rather than counted along. Walking `inds` alongside the vertices writes every entry,
    # so a reused buffer needs no clearing first.
    remap = buffer
    length(remap) < g.nv && resize!(remap, g.nv)
    nkept = 0
    removal = iterate(inds)
    for v in Base.OneTo(g.nv)
        if !isnothing(removal) && first(removal) == v
            remap[v] = 0
            removal = iterate(inds, last(removal))
        else
            nkept += 1
            remap[v] = nkept
        end
    end

    # Both modes keep the same neighbors in the same order and differ only in where they put them:
    # compactifying appends each surviving list to a fresh edgelist, while the default writes each list
    # back over itself. Either way the write position never overtakes the read position.
    edgelist = compactify ? Vector{Cint}(undef, g.nde) : g.e
    written = 0
    for v in Base.OneTo(g.nv)
        offset, olddegree = Int(g.v[v]), Int(g.d[v])
        kept = remap[v]
        target = compactify ? written : offset

        degree = 0
        if !iszero(kept)
            for pos in (offset + 1):(offset + olddegree)
                neighbor = remap[zero2one(g.e[pos])]
                iszero(neighbor) && continue
                degree += 1
                edgelist[target + degree] = one2zero(neighbor)
            end
            # `kept <= v`, so this only overwrites entries that have already been read
            g.v[kept] = target
            g.d[kept] = degree
            written += degree
        end

        if !compactify && olddegree > degree
            # a removed vertex frees its whole list, a surviving one whatever it no longer needs
            for pos in (offset + degree + 1):(offset + olddegree)
                g.e[pos] = NONEIGHBOR
            end
            g._freeslot = min(g._freeslot, offset + degree + 1)
        end
    end

    if compactify
        resize!(edgelist, written)
        g.e = edgelist
        g._freeslot = written + 1
    end
    resize!(g.v, nkept)
    resize!(g.d, nkept)
    deleteat!(g._labels, inds)

    g.nv = nkept
    g.nde = written
    g.iscanon = false
    return true
end

"""
    rem_vertex!(g::SparseNautyGraph, i::Integer; compactify=false, buffer=Vector{Cint}(undef, nv(g)))

Remove vertex `i` from `g`. Return `false` without modifying `g` if `i` is not a vertex of `g`.

See [`rem_vertices!`](@ref) for what `compactify` and `buffer` do.
"""
Graphs.rem_vertex!(g::SparseNautyGraph, i::Integer; kwargs...) = rem_vertices!(g, i:i; kwargs...)

function Graphs.blockdiag(g::SparseNautyGraph{D1}, h::SparseNautyGraph{D2}) where {D1,D2}
    nv = g.nv + h.nv
    nde = g.nde + h.nde
    v = [g.v; h.v .+ length(g.e)]
    d = [g.d; h.d]
    # `h`'s free slots have to stay free: shifting `NONEIGHBOR` would turn them into real vertices
    e = Vector{Cint}(undef, length(g.e) + length(h.e))
    copyto!(e, g.e)
    for (k, neighbor) in enumerate(h.e)
        e[length(g.e) + k] = ifelse(neighbor == NONEIGHBOR, neighbor, neighbor + Cint(g.nv))
    end
    labels = [g._labels; h._labels]
    iscanon = false

    D = D1 || D2
    # `g.e` is copied over unchanged, so its free slots are still the first ones in the result
    return SparseNautyGraph{D}(nv, nde, v, d, e, labels, iscanon, g._freeslot)
end