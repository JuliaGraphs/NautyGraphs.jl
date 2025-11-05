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

const DEFAULTOPTIONS16 = NautyOptions(C_NULL; digraph_or_loops=true, ignorelabels=false, groupinfo=false)
const DEFAULTOPTIONS32 = NautyOptions(C_NULL; digraph_or_loops=true, ignorelabels=false, groupinfo=false)
const DEFAULTOPTIONS64 = NautyOptions(C_NULL; digraph_or_loops=true, ignorelabels=false, groupinfo=false)
default_options(::DenseNautyGraph{D,UInt16}) where {D} = DEFAULTOPTIONS16
default_options(::DenseNautyGraph{D,UInt32}) where {D} = DEFAULTOPTIONS32
default_options(::DenseNautyGraph{D,UInt64}) where {D} = DEFAULTOPTIONS64

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

function _densenauty(g::DenseNautyGraph{D,W}, options::NautyOptions=default_options(g), statistics::NautyStatistics=NautyStatistics()) where {D,W}
    # TODO: allow the user to pass pre-allocated arrays for lab, ptn, orbits, canong in a safe way.
    n, m = g.graphset.n, g.graphset.m

    lab, ptn = vertexlabels2labptn(labels(g))
    orbits = zeros(Cint, n)
    canong = Graphset{W}(n, m)

    _ccall_densenauty(g, lab, ptn, orbits, options, statistics, canong)

    canonperm = (lab .+= 1)
    return canong, canonperm, orbits, statistics
end

@generated function _ccall_densenauty(g::DenseNautyGraph{D,W}, lab, ptn, orbits, options, statistics, canong) where {D,W}
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

"""
    nauty(g::AbstractNautyGraph, [options::NautyOptions; canonize=false])

Compute a graph `g`'s canonical form and automorphism group.
"""
function nauty(::AbstractNautyGraph, ::NautyOptions; kwargs...) end

function nauty(g::DenseNautyGraph, options::NautyOptions=default_options(g); canonize=false)
    if is_directed(g) && !isone(options.digraph)
        error("Nauty options need to match the directedness of the input graph. Make sure to instantiate options with `digraph=true` if the input graph is directed.")
    end
    if !isone(options.getcanon)
        # Right now, all implemented functionality is based on computing the canonical form, so it makes no sense to run nauty without computing it.
        error("`options.getcanon` needs to be enabled.")
    end

    canong, canonperm, orbits, statistics = _densenauty(g, options)
    # generators = Vector{Cint}[] # TODO: extract generators from nauty call
    autg = AutomorphismGroup(statistics.grpsize1 * 10^statistics.grpsize2, orbits)

    if canonize
        _copycanon!(g, canong, canonperm)
        g.iscanon = true
    end
    return canonperm, autg
end

"""
    canonize!(g::AbstractNautyGraph)

Reorder `g`'s vertices into canonical order and return the permutation used.
"""
function canonize!(::AbstractNautyGraph) end

function canonize!(g::DenseNautyGraph)
    iscanon(g) && return canonical_permutation(g)
    canong, canonperm, _ = _densenauty(g)
    _copycanon!(g, canong, canonperm)
    return canonperm
end
function _copycanon!(g, canong, canonperm)
    copy!(g.graphset, canong)
    permute!(g._labels, canonperm)
    g.iscanon = true
    return
end

"""
    canonical_permutation(g::AbstractNautyGraph)

Return the permutation `p` needed to canonize `g`, meaning that `g[p]` is canonical.
"""
function canonical_permutation(::AbstractNautyGraph) end

function canonical_permutation(g::DenseNautyGraph)
    iscanon(g) && return collect(Cint(1):Cint(nv(g))) # to be type stable, this needs to be Cints
    _, canonperm, _ = _densenauty(g)
    return canonperm
end

"""
    is_isomorphic(g::AbstractNautyGraph, h::AbstractNautyGraph)

Check whether two graphs `g` and `h` are isomorphic to each other by comparing their canonical forms.
"""
function is_isomorphic(::AbstractNautyGraph, ::AbstractNautyGraph) end

function is_isomorphic(g::DenseNautyGraph, h::DenseNautyGraph)
    iscanon(g) && iscanon(h) && return g == h
    canong, permg, _ = _densenauty(g)
    canonh, permh, _ = _densenauty(h)
    return canong == canonh && view(g._labels, permg) == view(h._labels, permh)
end
≃(g::AbstractNautyGraph, h::AbstractNautyGraph) = is_isomorphic(g, h)

"""
    canonical_id(g::AbstractNautyGraph)

Hash the canonical version of `g`, using the first 128 bits returned by the SHA256 algorithm.

The canonical id has the property that `is_isomorphic(g1, g2) == true` implies `canonical_id(g1) == canonical_id(g2)`. The converse usually holds as well, 
but in very rare cases, hash collisions may cause non-isomorphic graphs to have the same canonical id. 
"""
function canonical_id end

function canonical_id(g::DenseNautyGraph)
    if iscanon(g)
        return _SHAhash(g.graphset, g._labels)
    else
        canong, canonperm, _ = _densenauty(g)
        return _SHAhash(canong, @view g._labels[canonperm])
    end
end

function _SHAhash(x...)
    io = IOBuffer()
    write(io, (htol(x) for x in x)...)
    return reinterpret(UInt128, SHA.sha256(take!(io)))[1]
end
