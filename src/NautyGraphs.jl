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

function __init__()
    _GENERATOR_CALLBACK[] = @cfunction(_record_generator, Cvoid,
            (Cint, Ptr{Cint}, Ptr{Cint}, Cint, Cint, Cint))
    _LEVEL_CALLBACK[] = @cfunction(_record_level, Cvoid,
            (Ptr{Cint}, Ptr{Cint}, Cint, Ptr{Cint}, Ptr{Cvoid}, Cint, Cint, Cint, Cint, Cint, Cint))
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
    SpNautyGraph,
    SpNautyDiGraph,
    DenseNautyGraph,
    SparseNautyGraph,
    AutomorphismGroup,
    automorphism_group,
    order,
    orbits,
    orbit_partition,
    generators,
    labels,
    label, 
    setlabels!,
    setlabel!,
    iscanon,
    nauty,
    canonical,
    canonize!,
    canonical_permutation,
    canonical_id,
    is_isomorphic,
    ≃
end
