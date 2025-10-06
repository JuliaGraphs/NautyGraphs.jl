libnauty(::Type{UInt16}) = nauty_jll.libnautyTS
libnauty(::Type{UInt32}) = nauty_jll.libnautyTW
libnauty(::Type{UInt64}) = nauty_jll.libnautyTL
libnauty(::DenseNautyGraph{D,W}) where {D,W} = libnauty(W)

mutable struct NautyOptions
    getcanon::Cint # Warning: setting getcanon to false means that nauty will NOT compute the canonical representative, which may lead to unexpected results.
    digraph::Cbool # This needs to be true if the graph is directed or has loops. Disabling this option for undirected graphs with no loops may increase performance.
    writeautoms::Cbool
    writemarkers::Cbool
    defaultptn::Cbool
    cartesian::Cbool
    linelength::Cint

    outfile::Ptr{Cvoid}
    userrefproc::Ptr{Cvoid}
    userautomproc::Ptr{Cvoid}
    userlevelproc::Ptr{Cvoid}
    usernodeproc::Ptr{Cvoid}
    usercanonproc::Ptr{Cvoid}
    invarproc::Ptr{Cvoid}

    tc_level::Cint
    mininvarlevel::Cint
    maxinvarlevel::Cint
    invararg::Cint

    dispatch::Ptr{Cvoid}

    schreier::Cbool
    extra_options::Ptr{Cvoid}

    function NautyOptions(dispatch_pointer::Ptr{Cvoid}; digraph_or_loops, ignorelabels, groupinfo)
        return new(1, digraph_or_loops, groupinfo, false, ignorelabels, false, 78,
                C_NULL, C_NULL, C_NULL, C_NULL, C_NULL, C_NULL, C_NULL,
                100, 0, 1, 0,
                dispatch_pointer,
                false, C_NULL
    )
    end
end
@generated function NautyOptions(::Type{W}; digraph_or_loops=true, ignorelabels=false, groupinfo=false) where {W}
    return :(NautyOptions(cglobal((:dispatch_graph, $(libnauty(W))), Cvoid); digraph_or_loops, ignorelabels, groupinfo))
end

const DEFAULTOPTIONS_DENSE16 = NautyOptions(C_NULL; digraph_or_loops=true, ignorelabels=false, groupinfo=false)
const DEFAULTOPTIONS_DENSE32 = NautyOptions(C_NULL; digraph_or_loops=true, ignorelabels=false, groupinfo=false)
const DEFAULTOPTIONS_DENSE64 = NautyOptions(C_NULL; digraph_or_loops=true, ignorelabels=false, groupinfo=false)
const DEFAULTOPTIONS_SPARSE = NautyOptions(C_NULL; digraph_or_loops=true, ignorelabels=false, groupinfo=false)

default_options(::DenseNautyGraph{D,UInt16}) where {D} = DEFAULTOPTIONS_DENSE16
default_options(::DenseNautyGraph{D,UInt32}) where {D} = DEFAULTOPTIONS_DENSE32
default_options(::DenseNautyGraph{D,UInt64}) where {D} = DEFAULTOPTIONS_DENSE64
default_options(::SparseNautyGraph) = DEFAULTOPTIONS_SPARSE

mutable struct NautyStatistics
    grpsize1::Cdouble
    grpsize2::Cint
    numorbits::Cint
    numgenerators::Cint
    errstatus::Cint
    numnodes::Culong
    numbadleaves::Culong
    maxlevel::Cint
    tctotal::Culong
    canupdates::Culong
    invapplics::Culong
    invsuccesses::Culong
    invarsuclevel::Cint

    NautyStatistics() = new(
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    )
end

struct AutomorphismGroup
    n::Float64
    orbits::Vector{Cint}
    # generators::Vector{Vector{Cint}} #TODO: not implemented
end

function _nauty(g::DenseNautyGraph{D,W}, options::NautyOptions=default_options(g), statistics::NautyStatistics=NautyStatistics()) where {D,W}
    # TODO: allow the user to pass pre-allocated arrays for lab, ptn, orbits, canong in a safe way.
    n, m = g.graphset.n, g.graphset.m

    lab, ptn = vertexlabels2labptn(g.labels)
    orbits = zeros(Cint, n)
    canong = Graphset{W}(n, m)

    _ccall_nauty(g, lab, ptn, orbits, options, statistics, canong)
    canonperm = (lab .+= 1)
    return canong, canonperm, orbits, statistics
end
function _nauty(g::SparseNautyGraph{D}, options::NautyOptions=default_options(g), statistics::NautyStatistics=NautyStatistics()) where {D}
    lab, ptn = vertexlabels2labptn(g.labels)
    orbits = zeros(Cint, nv(g))
    canong = SparseNautyGraph{D}(nv(g))

    _ccall_nauty(g, lab, ptn, orbits, options, statistics, canong)
    canonperm = (lab .+= 1)
    return canong, canonperm, orbits, statistics
end

@generated function _ccall_nauty(g::DenseNautyGraph{D,W}, lab, ptn, orbits, options, statistics, canong) where {D,W}
    return quote @ccall $(libnauty(W)).densenauty(
        g.graphset.words::Ref{W},
        lab::Ref{Cint},
        ptn::Ref{Cint},
        orbits::Ref{Cint},
        Ref(options)::Ref{NautyOptions},
        Ref(statistics)::Ref{NautyStatistics},
        g.graphset.m::Cint,
        g.graphset.n::Cint,
        canong.words::Ref{W})::Cvoid end
end
@generated function _ccall_nauty(g::SparseNautyGraph, lab, ptn, orbits, options, statistics, canong)
    return quote @ccall $(libnauty(g)).sparsenauty(
        Ref(g)::Ref{SparseGraphGraphRep},
        lab::Ref{Cint},
        ptn::Ref{Cint},
        orbits::Ref{Cint},
        Ref(options)::Ref{NautyOptions},
        Ref(statistics)::Ref{NautyStatistics},
        Ref(canong)::Ref{SparseGraphGraphRep})::Cvoid end
end

function _sethash!(g::DenseNautyGraph, canong::Graphset, canonperm)
    # Base.hash skips elements in arrays of length >= 8192
    # Use SHA in these cases
    canong_hash = length(canong) >= 8192 ? hash_sha(canong) : hash(canong)
    labels_hash = @views length(g.labels) >= 8192 ? hash_sha(g.labels[canonperm]) : hash(g.labels[canonperm])

    hashval = hash(labels_hash, canong_hash)
    g.hashval = hashval
    return
end
function _canonize!(g::DenseNautyGraph, canong::Graphset, canonperm)
    copy!(g.graphset, canong)
    permute!(g.labels, canonperm)
    return
end


"""
    nauty(g::AbstractNautyGraph, [options::NautyOptions]; [canonize=false])

Compute a graph `g`'s canonical form and automorphism group.
"""
function nauty(::AbstractNautyGraph, ::NautyOptions; kwargs...) end

function nauty(g::DenseNautyGraph, options::NautyOptions=default_options(g); canonize=false, compute_hash=true)
    if is_directed(g) && !isone(options.digraph)
        error("Nauty options need to match the directedness of the input graph. Make sure to instantiate options with `digraph=true` if the input graph is directed.")
    end
    if !isone(options.getcanon)
        # Right now, all implemented functionality is based on computing the canonical form, so it makes no sense to run nauty without computing it.
        error("`options.getcanon` needs to be enabled.")
    end

    canong, canonperm, orbits, statistics = _nauty(g, options)
    # generators = Vector{Cint}[] # TODO: extract generators from nauty call
    autg = AutomorphismGroup(statistics.grpsize1 * 10^statistics.grpsize2, orbits)

    compute_hash && _sethash!(g, canong, canonperm)
    canonize && _canonize!(g, canong, canonperm)
    return canonperm, autg
end

"""
    canonize!(g::AbstractNautyGraph)

Reorder `g`'s vertices to be in canonical order. Returns the permutation `p` used to canonize `g`.
"""
function canonize!(::AbstractNautyGraph) end

function canonize!(g::DenseNautyGraph)
    canong, canonperm, _ = _nauty(g)
    _sethash!(g, canong, canonperm)
    _canonize!(g, canong, canonperm)
    return canonperm
end

"""
    canonical_permutation(g::AbstractNautyGraph)

Return the permutation `p` needed to canonize `g`. This permutation satisfies `g[p] = canong`.
"""
function canonical_permutation(::AbstractNautyGraph) end

function canonical_permutation(g::DenseNautyGraph)
    _, canonperm, _ = _nauty(g)
    return canonperm
end

"""
    is_isomorphic(g::AbstractNautyGraph, h::AbstractNautyGraph)

Check whether two graphs `g` and `h` are isomorphic to each other by comparing their canonical forms.
"""
function is_isomorphic(::AbstractNautyGraph, ::AbstractNautyGraph) end

function is_isomorphic(g::DenseNautyGraph, h::DenseNautyGraph)
    canong, permg, _ = _nauty(g)
    canonh, permh, _ = _nauty(h)
    return canong == canonh && view(g.labels, permg) == view(h.labels, permh)
end
≃(g::AbstractNautyGraph, h::AbstractNautyGraph) = is_isomorphic(g, h)


"""
    ghash(g::AbstractNautyGraph)

Hash the canonical version of `g`, so that (up to hash collisions) `ghash(g1) == ghash(g2)` implies `is_isomorphic(g1, g2) == true`.
Hashes are computed using `Base.hash` for small graphs (nv < 8192), or using the first 64 bits of `sha256` for larger graphs.
"""
function ghash(::AbstractNautyGraph) end

function ghash(g::DenseNautyGraph)
    if !isnothing(g.hashval)
        return g.hashval
    end

    canong, canonperm, _ = _nauty(g)
    _sethash!(g, canong, canonperm)
    return g.hashval
end