mutable struct SparseNautyGraph{D} <: AbstractNautyGraph{Int}
    nv::Int             # number of vertices
    nde::Int            # number of directed edges
    v::Vector{Csize_t}  # edgelist positions of vertices
    d::Vector{Cint}     # vertex degrees
    e::Vector{Cint}     # edgelist
    labels::Vector{Int} # vertex labels
end
function SparseNautyGraph{D}(n; vertex_labels=nothing) where {D}
    v = ones(Csize_t, n)
    d = zeros(Cint, n)
    e = -ones(Cint, 0) # encode unused values as -1
    if isnothing(vertex_labels)
        vertex_labels = zeros(Int, n)
    end
    return SparseNautyGraph{D}(n, 0, v, d, e, vertex_labels)
end

libnauty(::SparseNautyGraph) = nauty_jll.libnautyTL
libnauty(::Type{<:SparseNautyGraph}) = nauty_jll.libnautyTL

# C-compatible representation of a sparsenautygraph
mutable struct SparseGraphGraphRep
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
function Base.cconvert(::Type{Ref{SparseGraphGraphRep}}, sref::Ref{<:SparseNautyGraph})
    s = sref[]
    cstr = SparseGraphGraphRep(s.nde, pointer(s.v), s.nv, pointer(s.d), pointer(s.e), C_NULL, length(s.v), length(s.d), length(s.e), 0)
    return (s, cstr)
end
function Base.unsafe_convert(::Type{Ref{SparseGraphGraphRep}}, x::Tuple{<:SparseNautyGraph,SparseGraphGraphRep})
    _, cstr = x
    return convert(Ptr{SparseGraphGraphRep}, pointer_from_objref(cstr))
end
@generated function sortlists!(g::SparseNautyGraph)
    # Sort the lists in the graph rep into some reference order
    return quote
        @ccall $(libnauty(g)).sortlists_sg(Ref(g)::Ref{SparseGraphGraphRep})::Cvoid
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
    # Reorder the edgelists into reference order before taking the hash
    sortlists!(g)
    return hash(g.labels, hash(g.v, hash(g.d, hash(g.e, h))))
end

function Base.:(==)(g::SparseNautyGraph{D1}, h::SparseNautyGraph{D2}) where {D1, D2}
    return D1 == D2 && 
    labels(g) == labels(h) && 
    Bool(@ccall ll.aresame_sg(Ref(g)::Ref{SparseGraphGraphRep}, Ref(h)::Ref{SparseGraphGraphRep})::Cint)
end

Graphs.nv(g::SparseNautyGraph) = g.nv
Graphs.ne(g::SparseNautyGraph) = is_directed(g) ? g.nde : (g.nde + sum(has_edge(g, i, i) for i in vertices(g))) ÷ 2
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
@inline function Graphs.outneighbors(g::SparseNautyGraph, v::Integer)
    # following the Graph.jl implementation, there is no boundscheck here
    return (g.e[g.v[v] + i] for i in 0:g.d[v]-1)
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

Graphs.is_directed(::SparseNautyGraph{D}) where {D} = D
Graphs.is_directed(::Type{SparseNautyGraph{D}}) where {D} = D

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
    idx = g.v[i] + g.d[i]
    if idx in eachindex(g.e) && g.e[idx] == NONEIGHBOR
        g.e[idx] = j
    else
        insert!(g.e, idx, j)
    end
    @views g.v[i+1:end] .+= 1
    g.d[i] += 1
    g.nde += 1
    return
end

function Graphs.add_vertices!(g::SparseNautyGraph, n::Integer; vertex_labels=0)
    vertex_labels isa Number || n != length(vertex_labels) && throw(ArgumentError("Incompatible length: trying to add `n=$n` vertices, but`vertex_labels` has length $(length(vertex_labels))."))

    nold = g.nv
    nnew = nold + n
    resize!(g.v, nnew)
    resize!(g.d, nnew)
    resize!(g.labels, nnew)

    g.v[nold+1:end] .= g.v[nold]
    g.d[nold+1:end] .= 0
    g.labels[nold+1:end] .= vertex_labels

    g.nv = nnew
    return true
end

