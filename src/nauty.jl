libnauty(::Type{UInt16}) = nauty_jll.libnautyTS
libnauty(::Type{UInt32}) = nauty_jll.libnautyTW
libnauty(::Type{UInt64}) = nauty_jll.libnautyTL

"""
    NautyOptions

Records all options that affect nauty's execution. Mirrors nauty's `optionblk`, see the nauty manual for details.

!!! warning "Options can change the canonical form"

    Nauty documents `digraph`, `defaultptn`, `tc_level`, `userrefproc`, `invarproc`,
    `mininvarlevel`, `maxinvarlevel` and `invararg`  as affecting the canonical
    labeling. Canonical forms (and hence [`canonical_id`](@ref)) are only comparable between
    graphs processed with the same values for these fields. In particular `digraph=true` on an
    undirected graph is legal but both slower and, in general, a *different* canonical labeling
    than `digraph=false`.
"""
struct NautyOptions
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
end

"""
    NautyOptions(g::AbstractNautyGraph; digraph_or_loops=true, ignorelabels=false)

Build the options for running nauty on graph `g`.

# Keyword arguments
- `digraph_or_loops`: must be `true` if `g` is directed or has loops. Setting it
  to `false` for a simple undirected graph is faster, but changes the canonical form.
- `ignorelabels`: if `true`, all vertices are treated as having the same
  label, so `g`'s vertex labels are ignored.

!!! warning

    Setting `digraph_or_loops` to `false` if `g` is directed or contains loops will lead to silently wrong results.
    Even if `digraph_or_loops=false` is valid, this option may change the canonical form, and with it graph hashes
    and `canonical_id`.
"""
@generated function NautyOptions(::DenseNautyGraph{D,W}; digraph_or_loops=true, ignorelabels=false) where {D,W}
    return :(_options(cglobal((:dispatch_graph, $(libnauty(W))), Cvoid), digraph_or_loops, ignorelabels))
end
@generated function NautyOptions(::SparseNautyGraph; digraph_or_loops=true, ignorelabels=false)
    return :(_options(cglobal((:dispatch_sparse, $(libnauty(UInt64))), Cvoid), digraph_or_loops, ignorelabels))
end

# Fill in the fields that this package does not expose. `dispatch_pointer` selects the dense or
# sparse version of nauty, and has to match the graph the options are used with.
@inline function _options(dispatch_pointer::Ptr{Cvoid}, digraph_or_loops, ignorelabels)
    return NautyOptions(1, digraph_or_loops, false, false, ignorelabels, false, 78,
            C_NULL, C_NULL, C_NULL, C_NULL, C_NULL, C_NULL, C_NULL,
            100, 0, 1, 0,
            dispatch_pointer,
            false, C_NULL
    )
end

"""
    NautyOptions(options::NautyOptions; kwargs...)

Copy `options`, overriding the given fields.
"""
@inline function NautyOptions(options::NautyOptions;
        getcanon=options.getcanon, digraph=options.digraph, writeautoms=options.writeautoms,
        writemarkers=options.writemarkers, defaultptn=options.defaultptn,
        cartesian=options.cartesian, linelength=options.linelength, tc_level=options.tc_level,
        mininvarlevel=options.mininvarlevel, maxinvarlevel=options.maxinvarlevel,
        invararg=options.invararg, schreier=options.schreier)
    return NautyOptions(getcanon, digraph, writeautoms, writemarkers, defaultptn, cartesian,
            linelength,
            options.outfile, options.userrefproc, options.userautomproc, options.userlevelproc,
            options.usernodeproc, options.usercanonproc, options.invarproc,
            tc_level, mininvarlevel, maxinvarlevel, invararg,
            options.dispatch,
            schreier, options.extra_options
    )
end

"""
    NautyStatistics

Records the statistics nauty reports about a run. Mirrors nauty's `statsblk`, see the nauty
manual for details.
"""
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
end

"""
    NautyStatistics()

Build a zeroed set of statistics for nauty to write into.
"""
NautyStatistics() = NautyStatistics(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

const _DUMP_STATISTICS_KEY = :nautygraphs_dump_statistics

"""
    dump_statistics()

Return a scratch [`NautyStatistics`](@ref) for nauty to write into, so that a run does not have to
allocate a fresh one.

Nauty sets every field of `statsblk` on each run, so a reused object gives the same results as a fresh one.
The object is task-local, so concurrent calls never share it.
"""
@inline function dump_statistics()
    return get!(NautyStatistics, task_local_storage(), _DUMP_STATISTICS_KEY)::NautyStatistics
end

struct AutomorphismGroup
    n::Float64
    orbits::Vector{Cint}
    # generators::Vector{Vector{Cint}} #TODO: not implemented
end

function _nauty(g::AbstractNautyGraph, options::NautyOptions=NautyOptions(g), statistics::NautyStatistics=dump_statistics())
    # TODO: allow the user to pass pre-allocated arrays for lab, ptn, orbits, canong in a safe way.
    lab, ptn = vertexlabels2labptn(labels(g))
    orbits = zeros(Cint, nv(g))
    canong = if g isa DenseNautyGraph 
        Graphset{wordtype(g)}(g.graphset.n, g.graphset.m)
    else
        SparseGraphRep()
    end

    _ccall_nauty(g, lab, ptn, orbits, options, statistics, canong)
    canonperm = (lab .+= 1)
    return canong, canonperm, orbits, statistics
end

@generated function _ccall_nauty(g::DenseNautyGraph{D,W}, lab, ptn, orbits, options, statistics, canong) where {D,W}
    return quote @ccall $(libnauty(g)).densenauty(
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
    return quote 
        @ccall $(libnauty(g)).sparsenauty(
        Ref(g)::Ref{SparseGraphRep},
        lab::Ref{Cint},
        ptn::Ref{Cint},
        orbits::Ref{Cint},
        Ref(options)::Ref{NautyOptions},
        Ref(statistics)::Ref{NautyStatistics},
        Ref(canong)::Ref{SparseGraphRep})::Cvoid end
end

"""
    nauty(g::AbstractNautyGraph, [options::NautyOptions]; [canonize=false])

Compute a graph `g`'s canonical permutation and automorphism group. If `canonize=true`, `g` will additionally be canonized in-place.

See also [`canonize!`](@ref) and [`canonical_permutation`](@ref) for other tools related to canonization. 
"""
function nauty(g::AbstractNautyGraph, options::NautyOptions=NautyOptions(g); canonize=false)
    if is_directed(g) && !isone(options.digraph)
        throw(ArgumentError("Nauty options need to match the directedness of the input graph. Make sure to instantiate options with `digraph=true` if the input graph is directed."))
    end
    if !isone(options.getcanon)
        # Right now, all implemented functionality is based on computing the canonical form, so it makes no sense to run nauty without computing it.
        throw(ArgumentError("`options.getcanon` needs to be enabled."))
    end

    canong, canonperm, orbits, statistics = _nauty(g, options)
    # generators = Vector{Cint}[] # TODO: extract generators from nauty call
    autg = AutomorphismGroup(statistics.grpsize1 * 10^statistics.grpsize2, orbits)

    if canonize
        _copycanon!(g, canong, canonperm)
        g.iscanon = true
    end
    
    # free memory allocated by nauty for sparse graphs
    canong isa SparseGraphRep && _free_sparsegraphrep(canong)
    return canonperm, autg
end

"""
    canonize!(g::AbstractNautyGraph)

Reorder `g`'s vertices into canonical order and return the permutation used.

See also [`nauty`](@ref) and [`canonical_permutation`](@ref) for other tools related to canonization.
"""
function canonize! end

function canonize!(g::AbstractNautyGraph)
    iscanon(g) && return canonical_permutation(g)
    canong, canonperm, _ = _nauty(g)
    _copycanon!(g, canong, canonperm)
    canong isa SparseGraphRep && _free_sparsegraphrep(canong)
    return canonperm
end

function _copycanon!(g::DenseNautyGraph, canong::Graphset, canonperm)
    copy!(g.graphset, canong)
    permute!(g._labels, canonperm)
    g.iscanon = true
    return
end
function _copycanon!(g::SparseNautyGraph, canong::SparseGraphRep, canonperm)
    _unsafe_copyfromsparsegraphrep!(g, canong)
    permute!(g._labels, canonperm)
    g.iscanon = true
    return
end


"""
    canonical_permutation(g::AbstractNautyGraph)

Return the permutation `p` needed to canonize `g`, meaning that `g[p]` is canonical.

See also [`nauty`](@ref) and [`canonize!`](@ref) for other tools related to canonization.
"""
function canonical_permutation end

function canonical_permutation(g::AbstractNautyGraph)
    iscanon(g) && return collect(Cint(1):Cint(nv(g))) # to be type stable, this needs to be Cints
    canong, canonperm, _ = _nauty(g)
    canong isa SparseGraphRep && _free_sparsegraphrep(canong)
    return canonperm
end

"""
    is_isomorphic(g::AbstractNautyGraph, h::AbstractNautyGraph)

Check whether two graphs `g` and `h` are isomorphic to each other by comparing their canonical forms.
"""
function is_isomorphic end

function is_isomorphic(g::DenseNautyGraph, h::DenseNautyGraph)
    iscanon(g) && iscanon(h) && return g == h
    canong, permg, _ = _nauty(g)
    canonh, permh, _ = _nauty(h)
    isiso = canong == canonh && view(g._labels, permg) == view(h._labels, permh)
    
    return isiso
end

function is_isomorphic(g::SparseNautyGraph, h::SparseNautyGraph)
    iscanon(g) && iscanon(h) && return g == h
    canong, permg, _ = _nauty(g)
    canonh, permh, _ = _nauty(h)
    isiso = canong == canonh && view(g._labels, permg) == view(h._labels, permh)

    _free_sparsegraphrep(canong)
    _free_sparsegraphrep(canonh)
    return isiso
end
≃(g::AbstractNautyGraph, h::AbstractNautyGraph) = is_isomorphic(g, h)

"""
    canonical_id(g::AbstractNautyGraph)

Hash the canonical version of `g`, using the first 128 bits returned by the SHA256 algorithm.

The canonical id has the property that `is_isomorphic(g1, g2) == true` implies `canonical_id(g1) == canonical_id(g2)`. The converse usually holds as well, 
but in very rare cases, hash collisions may cause non-isomorphic graphs to have the same canonical id. 

!!! note

    `canonical_id` computes different results depending on whether the input is a dense `NautyGraph` or sparse `SpNautyGraph`, meaning that different graph
    types _cannot_ be compared using their canonical ids.

"""
function canonical_id(::AbstractNautyGraph) end

function canonical_id(g::DenseNautyGraph)
    if iscanon(g)
        return _SHAhash(g.graphset, g._labels)
    else
        canong, canonperm, _ = _nauty(g)
        return _SHAhash(canong, @view g._labels[canonperm])
    end
end

function canonical_id(g::SparseNautyGraph)
    # needs to work for 0 vertices
    if iscanon(g)
        sortlists!(g)
        return _SHAhash((_fadj_0based(g, i) for i in 1:nv(g))..., g._labels)
    else
        canong, canonperm, _ = _nauty(g)
        sortlists!(canong)
        h = _SHAhash((_fadj_0based(canong, i) for i in 1:nv(g))..., @view g._labels[canonperm])
        _free_sparsegraphrep(canong)
        return h
    end
end

function _SHAhash(x...)
    io = IOBuffer()
    write(io, (htol(x) for x in x)...)
    return reinterpret(UInt128, SHA.sha256(take!(io)))[1]
end
