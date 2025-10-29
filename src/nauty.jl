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

    lab, ptn = vertexlabels2labptn(g.labels)
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

    canonize && _copycanon!(g, canong, canonperm)
    return canonperm, autg
end

"""
    canonize!(g::AbstractNautyGraph)

Reorder `g`'s vertices to be in canonical order. Returns the permutation `p` used to canonize `g`.
"""
function canonize!(::AbstractNautyGraph) end

function canonize!(g::DenseNautyGraph)
    canong, canonperm, _ = _densenauty(g)
    _copycanon!(g, canong, canonperm)
    return canonperm
end
function _copycanon!(g, canong, canonperm)
    copy!(g.graphset, canong)
    permute!(g.labels, canonperm)
    g.iscanon = true
    return
end

"""
    canonical_permutation(g::AbstractNautyGraph)

Return the permutation `p` needed to canonize `g`. This permutation satisfies `g[p] = canong`.
"""
function canonical_permutation(::AbstractNautyGraph) end

function canonical_permutation(g::DenseNautyGraph)
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
    return canong == canonh && view(g.labels, permg) == view(h.labels, permh)
end
≃(g::AbstractNautyGraph, h::AbstractNautyGraph) = is_isomorphic(g, h)

"""
    ghash([hash_fn::Function], g::AbstractNautyGraph[, h::UInt])

Compute a hash of the canonical version of `g`, meaning that `is_isomorphic(g1, g2) == true` implies `ghash(g1) == ghash(g2)`. The converse usually holds as well, 
but in rare cases, hash collisions may cause non-isomorphic graphs to have the same hash. The likelihood of a hash collision occuring depends on the 
used hash function, which can optionally be specified via `hash_fn` (the required function signature is `hash_fn(x, h::UInt)`, the same as `Base.hash`).
If no hash function is given, the graph hash is computed using a (not cryptographically secure) hash function from nauty.

!!! warning "Warning"
    The default hash algorithm choice is not cryptographically secure and thus may lead to hash collisions. If you need high collision resistance, please pass a custom `hash_fn`
    with suitable security properties.

!!! warning "Warning"
    Using different hashing algorithms will result in different hash values. Before you compare different graph hashes, you have to 
    ensure that the hashes were computed with the same algorithm, or you will get meaningless results.
"""
function ghash end

function ghash(g::DenseNautyGraph, h::UInt=zero(UInt))
    if iscanon(g)
        return _sethash_dense(g.graphset, hash(g.labels, h))
    else
        canong, canonperm, _ = _densenauty(g)
        return _sethash_dense(canong, hash(@view(g.labels[canonperm]), h))
    end
    return h
end
function ghash(hash_fn::Function, g::DenseNautyGraph, h::UInt=zero(UInt))
    if iscanon(g)
        return _sethash_dense(hash_fn, g.graphset, hash_fn(g.labels, h))
    else
        canong, canonperm, _ = _densenauty(g)
        labs = hash_fn === Base.hash ? @view(g.labels[canonperm]) : g.labels[canonperm]
        return _sethash_dense(hash_fn, canong, hash_fn(labs, h))
    end
    return h
end

@generated function _sethash_dense(gset::Graphset{W}, h::UInt=zero(UInt)) where {W}
    return quote hashlong = @ccall $(libnauty(W)).hashgraph(
        gset.words::Ref{W},
        gset.m::Cint,
        gset.n::Cint,
        reinterpret(Clong, h)::Clong)::Clong 
        return reinterpret(UInt, hashlong)
    end
end
function _sethash_dense(hash_fn::Function, gset::Graphset, h::UInt=zero(UInt))
    # not all hash functions give the same result on (lazy) iterators and allocated arrays
    # to ensure compatiblility, we have to allocate here
    return hash_fn(collect(active_words(gset)), h)
end
