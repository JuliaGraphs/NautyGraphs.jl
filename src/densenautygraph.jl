"""
    DenseNautyGraph{D,W}

Memory-efficient graph format compatible with nauty. Can be directed (`D = true`) or undirected (`D = false`).
This graph format stores the adjacency matrix in bit vector form. `W` is the underlying
unsigned integer type that holds the individual bits of the graph's adjacency matrix (defaults to `UInt`).
"""
mutable struct DenseNautyGraph{D,W<:Unsigned} <: AbstractNautyGraph{Int}
    graphset::Graphset{W}
    _labels::Vector{Int}
    ne::Int
    iscanon::Bool
end
function DenseNautyGraph{D}(graphset::Graphset{W}; vertex_labels=nothing) where {D,W}
    if !isnothing(vertex_labels) && graphset.n != length(vertex_labels)
        throw(ArgumentError("The length of `graphset` is not compatible with length of `vertex_labels`. See the nauty user guide for how to correctly construct `graphset`."))
    end

    ne = D ? sum(graphset) : (sum(graphset) + tr(graphset)) ÷ 2

    if isnothing(vertex_labels)
        vertex_labels = zeros(Int, graphset.n)
    else
        vertex_labels = copy(vertex_labels)
    end
    return DenseNautyGraph{D,W}(graphset, vertex_labels, ne, false)
end


"""
    DenseNautyGraph{D}(n::Integer; [vertex_labels]) where {D}

Construct a `DenseNautyGraph` on `n` vertices and 0 edges. 
Can be directed (`D = true`) or undirected (`D = false`).
Vertex labels can optionally be specified.
"""
function DenseNautyGraph{D,W}(n::Integer; vertex_labels=nothing) where {D,W<:Unsigned}
    graphset = Graphset{W}(n)
    return DenseNautyGraph{D}(graphset; vertex_labels)
end
DenseNautyGraph{D}(n::Integer; vertex_labels=nothing) where {D} = DenseNautyGraph{D,UInt}(n; vertex_labels)

"""
    DenseNautyGraph{D}(; vertex_labels) where {D}

Construct a vertex-labeled `DenseNautyGraph` on `length(vertex_labels)` vertices and 0 edges.
Can be directed (`D = true`) or undirected (`D = false`).
"""
function DenseNautyGraph{D,W}(; vertex_labels) where {D,W<:Unsigned}
    return DenseNautyGraph{D}(length(vertex_labels); vertex_labels)
end
DenseNautyGraph{D}(; vertex_labels) where {D} = DenseNautyGraph{D,UInt}(; vertex_labels)

"""
    DenseNautyGraph{D}(A::AbstractMatrix; [vertex_labels]) where {D}

Construct a `DenseNautyGraph{D}` from the adjacency matrix `A`.
If `A[i][j] != 0`, an edge `(i, j)` is inserted. `A` must be a square matrix.
The graph can be directed (`D = true`) or undirected (`D = false`). If `D = false`, `A` must be symmetric.
Vertex labels can optionally be specified.
"""
function DenseNautyGraph{D,W}(A::AbstractMatrix; vertex_labels=nothing) where {D,W<:Unsigned}
    n, m = size(A)
    isequal(n, m) || throw(ArgumentError("Adjacency / distance matrices must be square"))
    D || issymmetric(A) || throw(ArgumentError("Adjacency / distance matrices must be symmetric"))
    graphset = Graphset{W}(A)
    return DenseNautyGraph{D}(graphset; vertex_labels)
end
DenseNautyGraph{D}(A::AbstractMatrix; vertex_labels=nothing) where {D} = DenseNautyGraph{D,UInt}(A; vertex_labels)

function DenseNautyGraph{D,W}(g::AbstractGraph; vertex_labels=nothing) where {D,W}
    ng = if g isa AbstractNautyGraph
            DenseNautyGraph{D,W}(nv(g); vertex_labels=isnothing(vertex_labels) ? labels(g) : vertex_labels)
        else
            DenseNautyGraph{D,W}(nv(g); vertex_labels)
    end
    for e in edges(g)
        add_edge!(ng, e)
        if !is_directed(g) && is_directed(ng)
            add_edge!(ng, reverse(e))
        end
    end
    return ng
end
DenseNautyGraph{D}(g::AbstractGraph; vertex_labels=nothing) where {D} = DenseNautyGraph{D,UInt}(g; vertex_labels)
DenseNautyGraph{W}(g::AbstractGraph; vertex_labels=nothing) where {W<:Unsigned} = DenseNautyGraph{is_directed(g),W}(g; vertex_labels)
DenseNautyGraph(g::AbstractGraph; vertex_labels=nothing) = DenseNautyGraph{is_directed(g),UInt}(g; vertex_labels)

"""
    DenseNautyGraph{D}(edge_list::Vector{<:AbstractEdge}; [vertex_labels]) where {D}

Construct a `DenseNautyGraph` from a vector of edges.
The number of vertices is the highest that is used in an edge in `edge_list`.
The graph can be directed (`D = true`) or undirected (`D = false`).
Vertex labels can optionally be specified.
"""
function DenseNautyGraph{D,W}(edge_list::Vector{<:AbstractEdge}; vertex_labels=nothing) where {D,W<:Unsigned}
    nvg = 0
    @inbounds for e in edge_list
        nvg = max(nvg, src(e), dst(e))
    end

    g = DenseNautyGraph{D,W}(nvg; vertex_labels)
    for edge in edge_list
        add_edge!(g, edge)
    end
    return g
end
DenseNautyGraph{D}(edge_list::Vector{<:AbstractEdge}; vertex_labels=nothing) where {D} = DenseNautyGraph{D,UInt}(edge_list; vertex_labels)

libnauty(::DenseNautyGraph{D,W}) where {D,W} = libnauty(W)
libnauty(::Type{DenseNautyGraph{D,W}}) where {D,W} = libnauty(W)

wordtype(g::DenseNautyGraph) = wordtype(g.graphset)

Base.copy(g::G) where {G<:DenseNautyGraph} = G(copy(g.graphset), copy(g._labels), g.ne, g.iscanon)
function Base.copy!(dest::G, src::G) where {G<:DenseNautyGraph}
    copy!(dest.graphset, src.graphset)
    copy!(dest._labels, src._labels)
    dest.ne = src.ne
    dest.iscanon = src.iscanon
    return dest
end

Base.show(io::Core.IO, g::DenseNautyGraph{false}) = print(io, "{$(nv(g)), $(ne(g))} undirected NautyGraph")
Base.show(io::Core.IO, g::DenseNautyGraph{true}) = print(io, "{$(nv(g)), $(ne(g))} directed NautyGraph")

Base.hash(g::DenseNautyGraph, h::UInt) = hash(g._labels, hash(g.graphset, h))
Base.:(==)(g::DenseNautyGraph, h::DenseNautyGraph) = (g.graphset == h.graphset) && (g._labels == h._labels)

# BASIC GRAPH API

Graphs.nv(g::DenseNautyGraph) = g.graphset.n
Graphs.ne(g::DenseNautyGraph) = g.ne
Graphs.vertices(g::DenseNautyGraph) = Base.OneTo(nv(g))
Graphs.has_vertex(g::DenseNautyGraph, v) = v ∈ vertices(g)
function Graphs.has_edge(g::DenseNautyGraph, s::Integer, d::Integer)
    has_vertex(g, s) && has_vertex(g, d) || return false
    return g.graphset[s, d]
end
function Graphs.outdegree(g::DenseNautyGraph, v::Integer)
    return sum(adjrow(g, v))
end
function Graphs.outneighbors(g::DenseNautyGraph, v::Integer)
    return findall(adjrow(g, v))
end
function adjrow(g::DenseNautyGraph, v::Integer)
    return @view g.graphset[v, :]
end

function Graphs.indegree(g::DenseNautyGraph, v::Integer)
    return sum(adjcol(g, v))
end
function Graphs.inneighbors(g::DenseNautyGraph, v::Integer)
    return findall(adjcol(g, v))
end
function adjcol(g::DenseNautyGraph, v::Integer)
    return @view g.graphset[:, v]
end

function Graphs.edges(g::DenseNautyGraph)
    return SimpleEdgeIter(g)
end
Base.eltype(::Type{<:SimpleEdgeIter{<:DenseNautyGraph{true}}}) = Graphs.SimpleGraphEdge{Int}
Base.eltype(::Type{<:SimpleEdgeIter{<:DenseNautyGraph{false}}}) = Graphs.SimpleDiGraphEdge{Int}
function Base.iterate(eit::SimpleEdgeIter{G}, state=(1, 1)) where {G<:DenseNautyGraph}
    g = eit.g
    n = nv(g)
    i0, j0 = state

    jstart = j0
    for i in i0:n
        for j in jstart:n
            g.graphset[i, j] && return Graphs.SimpleEdge(i, j), (i, j+1)
        end
        jstart = is_directed(g) ? 1 : i+1
    end
    return nothing
end
function Base.:(==)(e1::SimpleEdgeIter{<:DenseNautyGraph}, e2::SimpleEdgeIter{<:DenseNautyGraph})
    g = e1.g
    h = e2.g
    ne(g) == ne(h) || return false
    m = min(nv(g), nv(h))

    @views all(g.graphset[1:m, 1:m] .== h.graphset[1:m, 1:m]) || return false
    nv(g) == nv(h) && return true

    all(iszero, g.graphset[m+1:end, :]) || return false
    is_directed(g) || all(iszero, g.graphset[1:m, m+1:end]) || return false

    all(iszero, h.graphset[m+1:end, :]) || return false
    is_directed(h) || all(iszero, h.graphset[1:m, m+1:end]) || return false
    return true
end
function Base.:(==)(e1::SimpleEdgeIter{<:DenseNautyGraph}, e2::SimpleEdgeIter{<:Graphs.SimpleGraphs.AbstractSimpleGraph})
    g = e1.g
    h = e2.g
    ne(g) == ne(h) || return false
    is_directed(g) == is_directed(h) || return false

    m = min(nv(g), nv(h))
    for i in 1:m
        outneighbors(g, i) == Graphs.SimpleGraphs.fadj(h, i) || return false
    end
    nv(g) == nv(h) && return true

    all(iszero, g.graphset[m+1:end, :]) || return false
    is_directed(g) || all(iszero, g.graphset[1:m, m+1:end]) || return false

    for i in (m + 1):nv(h)
        isempty(Graphs.SimpleGraphs.fadj(h, i)) || return false
    end
    return true
end
Base.:(==)(e1::SimpleEdgeIter{<:Graphs.SimpleGraphs.AbstractSimpleGraph}, e2::SimpleEdgeIter{<:DenseNautyGraph}) = e2 == e1

Graphs.is_directed(::Type{<:DenseNautyGraph{D}}) where {D} = D

# GRAPH MODIFY METHODS
function Graphs.add_edge!(g::DenseNautyGraph, e::Edge)
    has_vertex(g, e.src) && has_vertex(g, e.dst) || return false
    edge_present = g.graphset[e.src, e.dst]
    edge_present && return false

    g.graphset[e.src, e.dst] = 1
    is_directed(g) || (g.graphset[e.dst, e.src] = 1)
    g.ne += 1
    g.iscanon = false
    return true
end

function Graphs.rem_edge!(g::DenseNautyGraph, e::Edge)
    has_vertex(g, e.src) && has_vertex(g, e.dst) || return false
    edge_present = g.graphset[e.src, e.dst]
    edge_present || return false

    g.graphset[e.src, e.dst] = 0
    is_directed(g) || (g.graphset[e.dst, e.src] = 0)
    g.ne -= 1
    g.iscanon = false
    return true
end

function Graphs.add_vertices!(g::DenseNautyGraph, n::Integer; vertex_labels=0)
    vertex_labels isa Number || n != length(vertex_labels) && throw(ArgumentError("Incompatible length: trying to add `n=$n` vertices, but`vertex_labels` has length $(length(vertex_labels))."))
    ng = nv(g)
    _add_vertices!(g.graphset, n)
    resize!(g._labels, ng + n)
    g._labels[ng+1:end] .= vertex_labels
    g.iscanon = false
    return n
end
Graphs.add_vertices!(g::DenseNautyGraph; vertex_labels) = Graphs.add_vertices!(g, length(vertex_labels); vertex_labels)
Graphs.add_vertex!(g::DenseNautyGraph; vertex_label::Integer=0) = Graphs.add_vertices!(g, 1; vertex_labels=vertex_label) > 0

function Graphs.rem_vertices!(g::DenseNautyGraph, inds)
    all(i->has_vertex(g, i), inds) || return false

    _rem_vertices!(g.graphset, inds)
    deleteat!(g._labels, inds)

    g.ne = is_directed(g) ? sum(g.graphset) : (sum(g.graphset) + tr(g.graphset)) ÷ 2
    g.iscanon = false
    return true
end
Graphs.rem_vertex!(g::DenseNautyGraph, i::Integer) = rem_vertices!(g, (i,))

function Graphs.blockdiag(g::DenseNautyGraph{D1,W}, h::DenseNautyGraph{D2}) where {D1,D2,W}
    ng, nh = nv(g), nv(h)

    gset = Graphset{wordtype(g.graphset)}(ng+nh)
    gset[1:ng, 1:ng] .= g.graphset
    gset[ng+1:end, ng+1:end] .= h.graphset
    D = D1 || D2
    return DenseNautyGraph{D,W}(gset; vertex_labels=vcat(labels(g), labels(h)))
end