module NautyGraphs

using Graphs, LinearAlgebra
using Graphs.SimpleGraphs: SimpleEdgeIter
import nauty_jll
import SHA

const Cbool = Cint
abstract type AbstractNautyGraph{T} <: AbstractGraph{T} end

include("utils.jl")
include("graphset.jl")
include("densenautygraph.jl")
include("nauty.jl")

const NautyGraph = DenseNautyGraph{false}
const NautyDiGraph = DenseNautyGraph{true}

function __init__()
    # global default options to nauty carry a pointer reference that needs to be initialized at runtime
    DEFAULTOPTIONS16.dispatch = cglobal((:dispatch_graph, libnauty(UInt16)), Cvoid)
    DEFAULTOPTIONS32.dispatch = cglobal((:dispatch_graph, libnauty(UInt32)), Cvoid)
    DEFAULTOPTIONS64.dispatch = cglobal((:dispatch_graph, libnauty(UInt64)), Cvoid)
    return
end

export
    add_edge!,
    rem_edge!,
    add_vertex!,
    add_vertices!,
    rem_vertex!,
    rem_vertices!,
    nv, ne, 
    vertices, edges,
    has_vertex, has_edge,
    inneighbors, outneighbors, neighbors,
    indegree, outdegree, degree,
    is_directed,
    edgetype,
    Edge

export
    AbstractNautyGraph,
    NautyGraph,
    NautyDiGraph,
    DenseNautyGraph,
    AutomorphismGroup,
    labels, 
    label, 
    setlabels!,
    setlabel!,
    iscanon,
    nauty,
    canonize!,
    canonical_permutation,
    canonical_id,
    is_isomorphic,
    ≃
end
