module NautyGraphs

using Graphs, LinearAlgebra, SHA
using Graphs.SimpleGraphs: SimpleEdgeIter
import nauty_jll

const Cbool = Cint
const HashType = UInt

abstract type AbstractNautyGraph{T} <: AbstractGraph{T} end

include("utils.jl")
include("graphset.jl")
include("densenautygraph.jl")
include("sparsenautygraph.jl")
include("nauty.jl")

const NautyGraph = DenseNautyGraph{false}
const NautyDiGraph = DenseNautyGraph{true}


function __init__()
    # global default options to nauty carry a pointer reference that needs to be initialized at runtime
    DEFAULTOPTIONS_DENSE16.dispatch = cglobal((:dispatch_graph, libnauty(UInt16)), Cvoid)
    DEFAULTOPTIONS_DENSE32.dispatch = cglobal((:dispatch_graph, libnauty(UInt32)), Cvoid)
    DEFAULTOPTIONS_DENSE64.dispatch = cglobal((:dispatch_graph, libnauty(UInt64)), Cvoid)
    DEFAULTOPTIONS_SPARSE.dispatch = cglobal((:dispatch_sparse, libnauty(UInt64)), Cvoid)
    return
end

export
    AbstractNautyGraph,
    NautyGraph,
    NautyDiGraph,
    DenseNautyGraph,
    SparseNautyGraph,
    AutomorphismGroup,
    labels,
    nauty,
    canonize!,
    canonical_permutation,
    is_isomorphic,
    ≃,
    ghash
end
