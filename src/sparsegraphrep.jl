const NONEIGHBOR = -1

mutable struct SparseNautyGraph{D} <: AbstractNautyGraph{Cint}
    nv::Int
    nde::Int
    v::Vector{Csize_t}
    d::Vector{Cint}
    e::Vector{Cint}

    function SparseNautyGraph{D}(n; ne=0)
        v = ones(Csize_t, n)
        d = zeros(Cint, n)
        e = -ones(Cint, ne)
        return new{D}(n, 0, v, d, e)
    end
end

mutable struct SparseGraphCStruct
    nde::Csize_t
    v::Ptr{Csize_t}  #index into edges
    nv::Cint
    d::Ptr{Cint}     #degrees
    e::Ptr{Cint}     #edges
    w::Ptr{Cint}
    vlen::Csize_t
    dlen::Csize_t
    elen::Csize_t
    wlen::Csize_t
end
function Base.cconvert(::Type{Ref{SparseGraphCStruct}}, sref::Ref{SparseNautyGraph})
    s = sref[]
    cstr = SparseGraphCStruct(s.nde, pointer(s.v), s.nv, pointer(s.d), pointer(s.e), C_NULL, length(s.v), length(s.d), length(s.e), 0)
    return (s, cstr)
end
function Base.unsafe_convert(::Type{Ref{SparseGraphCStruct}}, x::Tuple{SparseNautyGraph,SparseGraphCStruct})
    _, cstr = x
    return convert(Ptr{SparseGraphCStruct}, pointer_from_objref(cstr))
end

Graphs.is_directed(::SparseNautyGraph{D}) where {D} = D
Graphs.is_directed(::Type{SparseNautyGraph{D}}) where {D} = D

Graphs.vertices(g::SparseNautyGraph) = Base.OneTo(g.nv)
Graphs.nv(g::SparseNautyGraph) = g.nv
Graphs.ne(g::SparseNautyGraph) = is_directed(g) ? g.nde : (g.nde + sum(has_edge(g, i, i) for i in vertices(g))) ÷ 2

function Graphs.has_edge(g::SparseNautyGraph, s::Integer, d::Integer)
    for i in 0:g.d[s]-1
        g.e[g.v[s] + i] == d && return true
    end
    return false
end

function Graphs.outdegree(g::SparseNautyGraph, v::Integer)
    return g.d[v]
end
function Graphs.outneighbors(g::SparseNautyGraph, v::Integer)
    return [g.e[v + i] for i in 0:g.d[v]-1]
end

function Graphs.indegree(g::SparseNautyGraph, v::Integer)
    return is_directed(g) ? sum(has_edge(g, i, v) for i in vertices(g)) : outdegree(g, v)
end
function Graphs.inneighbors(g::SparseNautyGraph, v::Integer)
    return is_directed(g) ? findall(has_edge(g, i, v) for i in vertices(g)) : outneighbors(g, v)
end

function Graphs.edges(g::SparseNautyGraph)
    return SimpleEdgeIter(g)
end



function Graphs.add_edge!(g::SparseNautyGraph, i::Integer, j::Integer)
    has_vertex(g, i) && has_vertex(g, j) || return false
    has_edge(g, i, j) && return false

    _add_directed_edge!(g, i, j)
    if !is_directed(g) && i != j
        _add_directed_edge!(g, j, i)
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
    return
end

function Graphs.add_vertices!(srep::SparseNautyGraph, n::Integer)
    nnew = srep.nv + n
    resize!(srep.v, nnew)
    resize!(srep.d, nnew)

    srep.v[srep.nv+1:end] .= srep.v[srep.nv]
    srep.d[srep.nv+1:end] .= 0
    srep.nv = nnew
    return true
end

