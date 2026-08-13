module NautyGraphs

using Graphs, LinearAlgebra
using Graphs.SimpleGraphs: SimpleEdgeIter
import nauty_jll
import SHA

const Cbool = Cint

include("abstractnautygraph.jl")
include("utils.jl")
include("graphset.jl")
include("densenautygraph.jl")
include("sparsenautygraph.jl")
include("nauty.jl")
include("graphs_api_extensions.jl")

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
    SpNautyGraph,
    SpNautyDiGraph,
    DenseNautyGraph,
    SparseNautyGraph,
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
