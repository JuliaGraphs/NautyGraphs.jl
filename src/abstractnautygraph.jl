abstract type AbstractNautyGraph{T} <: AbstractGraph{T} end

"""
    labels(g::AbstractNautyGraph)

Return the vertex labels of `g`. 

Do not modify the vector of labels returned. Use [`setlabels!`](@ref) or [`setlabel!`](@ref) instead.
"""
@inline labels(g::AbstractNautyGraph) = g._labels

"""
    label(g::AbstractNautyGraph, i::Integer)

Return the label of vertex `i` of `g`.
"""
@inline label(g::AbstractNautyGraph, index::Integer) = g._labels[index]

"""
    setlabels!(g::AbstractNautyGraph, vertex_labels)

Set the vertex labels of `g` equal to `vertex_labels`.
"""
function setlabels!(g::AbstractNautyGraph, vertex_labels)
    g.iscanon = false
    g._labels .= vertex_labels
    return vertex_labels
end

"""
    setlabel!(g::AbstractNautyGraph, i::Integer, vertex_label)

Set the label of vertex `i` of `g` equal to `vertex_label`.
"""
function setlabel!(g::AbstractNautyGraph, index::Integer, vertex_label)
    g.iscanon = false
    g._labels[index] = vertex_label
    return vertex_label
end

"""
    iscanon(g::AbstractNautyGraph)

Return true if `g` has previously been canonized.

`iscanon(g) == false` does not necessarily imply that `g` is not in canonical form, it just means `g` has never
been explicitly canonized. This function should be considered internal and may be removed in future versions.
"""
@inline iscanon(g::AbstractNautyGraph) = g.iscanon

Graphs.edgetype(::AbstractNautyGraph) = Graphs.SimpleGraphs.SimpleEdge{Int}
Base.eltype(::AbstractNautyGraph{T}) where {T} = T
Base.zero(::G) where {G<:AbstractNautyGraph} = G(0)
Base.zero(::Type{G}) where {G<:AbstractNautyGraph} = G(0)

function _induced_subgraph(g::AbstractNautyGraph, iter)
    h, vmap = invoke(Graphs.induced_subgraph, Tuple{AbstractGraph,typeof(iter)}, g, iter)
    @views h._labels .= g._labels[vmap]
    h.iscanon = false
    return h, vmap
end
Graphs.induced_subgraph(g::AbstractNautyGraph, iter::AbstractVector{<:Integer}) = _induced_subgraph(g, iter)
Graphs.induced_subgraph(g::AbstractNautyGraph, iter::AbstractVector{Bool}) = _induced_subgraph(g, iter)
Graphs.induced_subgraph(g::AbstractNautyGraph, iter::AbstractVector{<:AbstractEdge}) = _induced_subgraph(g, iter)

Graphs.add_edge!(g::AbstractNautyGraph, i::Integer, j::Integer) = Graphs.add_edge!(g, edgetype(g)(i, j))
Graphs.rem_edge!(g::AbstractNautyGraph, i::Integer, j::Integer) = Graphs.rem_edge!(g, edgetype(g)(i, j))

function Base.hash(edgeiter::SimpleEdgeIter{<:AbstractNautyGraph}, h::UInt)
    for edge in edgeiter
        h = hash(edge, h)
    end
    return h
end