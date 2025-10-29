"""
    CanonGraph{G}

Canonical representation of a graph isomorphism class. Comparing canonical graphs is done 
via isomorphism checks.
"""
mutable struct CanonGraph{G<:AbstractNautyGraph} <: AbstractNautyGraph{Int}
    g::G
    function CanonGraph{G}(g; copy_graph=true) where {G<:AbstractNautyGraph}
        cg = new{G}(copy_graph ? copy(g) : g)
        canonize!(cg.g)
        return cg
    end
end
function CanonGraph(g::AbstractGraph)
    grep = is_directed(g) ? NautyDiGraph(g) : NautyGraph(g)
    return CanonGraph{typeof(grep)}(grep; copy_graph=false)
end


Base.copy(g::CanonGraph{G}) where {G} = CanonGraph{G}(copy(g.g))
function Base.copy!(dest::CanonGraph{G}, src::CanonGraph{G}) where {G}
    copy!(dest.g, src.g)
    return dest
end

Base.show(io::Core.IO, g::CanonGraph) = print(io, "{$(nv(g)), $(ne(g))} CanonGraph")

Base.hash(g::CanonGraph, h::UInt) = ghash(g.g, h)
Base.:(==)(g::CanonGraph, h::CanonGraph) = g.g == h.g # we always canonize the underlying graph, meaning we do not need to check for isomorphism here explicitly

# BASIC GRAPH API
labels(g::CanonGraph) = g.g.labels
Graphs.nv(g::CanonGraph) = nv(g.g)
Graphs.ne(g::CanonGraph) = ne(g.g)
Graphs.vertices(g::CanonGraph) = vertices(g.g)
Graphs.has_vertex(g::CanonGraph, v) = has_vertex(g.g, v)
Graphs.has_edge(g::CanonGraph, s::Integer, d::Integer) = has_edge(g.g, s, d)
Graphs.outdegree(g::CanonGraph, v::Integer) = outdegree(g.g, v)
Graphs.outneighbors(g::CanonGraph, v::Integer) = outneighbors(g.g, v)
Graphs.indegree(g::CanonGraph, v::Integer) = indegree(g.g, v)
Graphs.inneighbors(g::CanonGraph, v::Integer) = inneighbors(g.g, v)
Graphs.edges(g::CanonGraph) = edges(g.g)
Graphs.is_directed(::Type{CanonGraph{G}}) where {G} = is_directed(D)
Graphs.edgetype(g::CanonGraph) = edgetype(g.g)
Base.eltype(g::CanonGraph) = eltype(g.g)
Base.zero(g::CanonGraph) = zero(g.g)
Base.zero(::Type{CanonGraph{G}}) where {G} = zero(G)
Graphs.induced_subgraph(g::CanonGraph, iter::AbstractVector{<:Integer}) = let (g,perm) = induced_subgraph(g.g, iter); CanonGraph(g), perm end
Graphs.induced_subgraph(g::CanonGraph, iter::AbstractVector{Bool}) = let (g,perm) = induced_subgraph(g.g, iter); CanonGraph(g), perm end
Graphs.induced_subgraph(g::CanonGraph, iter::AbstractVector{<:AbstractEdge}) = let (g,perm) = induced_subgraph(g.g, iter); CanonGraph(g), perm end
# GRAPH MODIFY METHODS
Graphs.add_edge!(g::CanonGraph, e::Edge) = let res=add_edge!(g.g, e); canonize!(g.g); res end
Graphs.add_edge!(g::CanonGraph, i::Integer, j::Integer) = add_edge!(g, edgetype(g)(i, j))

Graphs.rem_edge!(g::CanonGraph, e::Edge) = let res=rem_edge!(g.g, e); canonize!(g.g); res end
Graphs.rem_edge!(g::CanonGraph, i::Integer, j::Integer) = Graphs.rem_edge!(g, edgetype(g)(i, j))

Graphs.add_vertices!(g::CanonGraph, n::Integer; vertex_labels=0) = let res=add_vertices!(g.g, n; vertex_labels); canonize!(g.g); res end
Graphs.add_vertex!(g::CanonGraph; vertex_label::Integer=0) = Graphs.add_vertices!(g, 1; vertex_labels=vertex_label) > 0

Graphs.rem_vertices!(g::CanonGraph, inds) = let res=rem_vertices!(g.g, inds); canonize!(g.g); res end
Graphs.rem_vertex!(g::CanonGraph, i::Integer) = rem_vertices!(g, (i,))

Graphs.blockdiag(g::CanonGraph{G}, h::CanonGraph) where {G} = CanonGraph{G}(blockdiag(g.g, h.g))