libnauty(::Type{UInt16}) = nauty_jll.libnautyTS
libnauty(::Type{UInt32}) = nauty_jll.libnautyTW
libnauty(::Type{UInt64}) = nauty_jll.libnautyTL

# `@cfunction` pointers go stale when they are serialized into a precompiled image, so these have
# to be created by `__init__` rather than at load time.
const _GENERATOR_CALLBACK = Ref(C_NULL)
const _LEVEL_CALLBACK = Ref(C_NULL)

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
    NautyOptions(g::AbstractNautyGraph; digraph_or_loops=true, ignorelabels=false,
                 generators=false, exact_order=false)

Build the options for running nauty on graph `g`.

# Keyword arguments
- `digraph_or_loops`: must be `true` if `g` is directed or has loops. Setting it
  to `false` for a simple undirected graph is faster, but changes the canonical form.
- `ignorelabels`: if `true`, all vertices are treated as having the same
  label, so `g`'s vertex labels are ignored.
- `generators`: if `true`, collect the generators of the automorphism group.
- `exact_order`: if `true`, collect the subgroup indices needed to report the automorphism group's
  [`order`](@ref) as an exact integer rather than a `Float64`.

!!! warning

    Setting `digraph_or_loops` to `false` if `g` is directed or contains loops will lead to silently wrong results.
    Even if `digraph_or_loops=false` is valid, this option may change the canonical form, and with it graph hashes
    and `canonical_id`.
"""
@generated function NautyOptions(::DenseNautyGraph{D,W}; digraph_or_loops=true, ignorelabels=false,
        generators=false, exact_order=false) where {D,W}
    return :(_options(cglobal((:dispatch_graph, $(libnauty(W))), Cvoid), digraph_or_loops, ignorelabels,
            generators, exact_order))
end
@generated function NautyOptions(::SparseNautyGraph; digraph_or_loops=true, ignorelabels=false,
        generators=false, exact_order=false)
    return :(_options(cglobal((:dispatch_sparse, $(libnauty(UInt64))), Cvoid), digraph_or_loops, ignorelabels,
            generators, exact_order))
end

# Fill in the fields that this package does not expose. `dispatch_pointer` selects the dense or
# sparse version of nauty, and has to match the graph the options are used with.
@inline function _options(dispatch_pointer::Ptr{Cvoid}, digraph_or_loops, ignorelabels, generators, exact_order)
    return NautyOptions(1, digraph_or_loops, false, false, ignorelabels, false, 78,
            C_NULL, C_NULL,
            generators ? _GENERATOR_CALLBACK[] : C_NULL,
            exact_order ? _LEVEL_CALLBACK[] : C_NULL,
            C_NULL, C_NULL, C_NULL,
            100, 0, 1, 0,
            dispatch_pointer,
            false, C_NULL
    )
end

"""
    NautyOptions(options::NautyOptions; kwargs...)

Copy `options`, overriding the given fields.

`generators` and `exact_order` are named as in [`NautyOptions(::AbstractNautyGraph)`](@ref) rather
than after the fields they set.
"""
@inline function NautyOptions(options::NautyOptions;
        getcanon=options.getcanon, digraph=options.digraph, writeautoms=options.writeautoms,
        writemarkers=options.writemarkers, defaultptn=options.defaultptn,
        cartesian=options.cartesian, linelength=options.linelength, tc_level=options.tc_level,
        mininvarlevel=options.mininvarlevel, maxinvarlevel=options.maxinvarlevel,
        invararg=options.invararg, schreier=options.schreier,
        generators=nothing, exact_order=nothing)
    userautomproc = isnothing(generators) ? options.userautomproc : (generators ? _GENERATOR_CALLBACK[] : C_NULL)
    userlevelproc = isnothing(exact_order) ? options.userlevelproc : (exact_order ? _LEVEL_CALLBACK[] : C_NULL)
    return NautyOptions(getcanon, digraph, writeautoms, writemarkers, defaultptn, cartesian,
            linelength,
            options.outfile, options.userrefproc, userautomproc, userlevelproc,
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

Nauty treats `statsblk` as write-only and sets every field on each run, so a reused object gives
the same results as a fresh one, with no need to zero it in between. The object is task-local, so
concurrent calls never share it.
"""
@inline function dump_statistics()
    return get!(NautyStatistics, task_local_storage(), _DUMP_STATISTICS_KEY)::NautyStatistics
end

const _NO_ERROR = Cint(0)
# Allocating the generator and growing the buffers are the only operations in the callbacks that
# can fail, so running out of memory is the only error they can report.
const _OUT_OF_MEMORY = Cint(1)

# Task-local sink for nauty's callbacks. A callback must not throw, because that would unwind
# through nauty's C frames, so it records an error code that is checked once the run is over.
mutable struct AutomorphismBuffer
    generators::Vector{Vector{Cint}}
    levelindices::Vector{Cint}
    errorcode::Cint
end
AutomorphismBuffer() = AutomorphismBuffer(Vector{Cint}[], Cint[], _NO_ERROR)

const _AUTOMORPHISM_BUFFER_KEY = :nautygraphs_automorphism_buffer

@inline function automorphism_buffer()
    return get!(AutomorphismBuffer, task_local_storage(), _AUTOMORPHISM_BUFFER_KEY)::AutomorphismBuffer
end

# nauty calls this once per generator of the automorphism group. `perm` points at `n` zero-based
# images and is only valid for the duration of the call.
function _record_generator(::Cint, perm::Ptr{Cint}, ::Ptr{Cint}, ::Cint, ::Cint, n::Cint)
    buffer = automorphism_buffer()
    try
        generator = Vector{Cint}(undef, n)
        GC.@preserve generator unsafe_copyto!(pointer(generator), perm, n)
        generator .+= one(Cint)
        push!(buffer.generators, generator)
    catch
        buffer.errorcode = _OUT_OF_MEMORY
    end
    return
end

# nauty calls this once per level of its search tree. `index` is the index of that level's point
# stabilizer in the group above it, so the indices multiply to the exact order of the group.
function _record_level(::Ptr{Cint}, ::Ptr{Cint}, ::Cint, ::Ptr{Cint}, ::Ptr{Cvoid}, ::Cint,
        index::Cint, ::Cint, ::Cint, ::Cint, ::Cint)
    buffer = automorphism_buffer()
    try
        push!(buffer.levelindices, index)
    catch
        buffer.errorcode = _OUT_OF_MEMORY
    end
    return
end

@inline function has_automorphism_callbacks(options::NautyOptions)
    return options.userautomproc != C_NULL || options.userlevelproc != C_NULL
end

function _reset_automorphism_buffer!()
    buffer = automorphism_buffer()
    # the previous run's generators were handed to the caller, so emptying them would mutate an
    # object that is still in use; the level indices never escape and can keep their capacity
    buffer.generators = Vector{Cint}[]
    empty!(buffer.levelindices)
    buffer.errorcode = _NO_ERROR
    return buffer
end

function _check_automorphism_buffer()
    automorphism_buffer().errorcode == _NO_ERROR || throw(OutOfMemoryError())
    return
end

"""
    AutomorphismGroup

The automorphism group of a graph, as reported by [`automorphism_group`](@ref) or [`nauty`](@ref).

Read it through [`order`](@ref), [`orbits`](@ref), [`orbit_partition`](@ref) and
[`generators`](@ref).
"""
struct AutomorphismGroup{S,G}
    order::S
    orbits::Vector{Cint}
    generators::G
end

"""
    order(autg::AutomorphismGroup)

Return the order of `autg`, which is the number of group elements.

The result is an exact `BigInt` if the group was computed with `exact_order=true`. Otherwise it is
a `Float64`, which carries about 16 significant digits, is exact up to roughly `10^12`.
"""
order(autg::AutomorphismGroup) = autg.order

"""
    generators(autg::AutomorphismGroup)

Return the generating permutations of `autg`. Generator `p` maps vertex `i` to `p[i]`.

The generators are only available if the group was computed with `generators=true`.
"""
generators(autg::AutomorphismGroup) = autg.generators

"""
    orbits(autg::AutomorphismGroup)

Return the vertex orbits of `autg`, labeled by their smallest vertex.

Vertices `i` and `j` share an orbit exactly if `orbits(autg)[i] == orbits(autg)[j]`. See
[`orbit_partition`](@ref) to get the orbits as separate vectors instead.
"""
orbits(autg::AutomorphismGroup) = autg.orbits

"""
    orbit_partition(autg::AutomorphismGroup)

Return the vertex orbits of `autg` as a vector of vertex vectors.

Both the orbits and the vertices within each orbit come out in increasing order. This allocates one
vector per orbit, so prefer [`orbits`](@ref) when the labelling is enough.
"""
function orbit_partition(autg::AutomorphismGroup)
    orbits = autg.orbits
    slots = zeros(Int, length(orbits))
    partition = Vector{Int}[]
    for v in eachindex(orbits)
        rep = orbits[v]
        if iszero(slots[rep])
            push!(partition, Int[])
            slots[rep] = length(partition)
        end
        push!(partition[slots[rep]], v)
    end
    return partition
end

function Base.show(io::IO, autg::AutomorphismGroup)
    print(io, "AutomorphismGroup of order ", autg.order, " on ", length(autg.orbits), " vertices")
    isnothing(autg.generators) || print(io, ", ", length(autg.generators), " generators")
    return
end

# Rewrite the automorphism group in the vertex numbering that canonizing gives the graph. This
# runs on nauty's own arrays rather than on an `AutomorphismGroup`, whose type is only pinned down
# once the flags are known.
@inline function _recanonize!(orbits, canonperm, generators::Bool)
    # `canonperm` maps a canonical vertex to the vertex it came from, `inverse` maps back
    inverse = invperm(canonperm)
    scratch = similar(orbits)
    generators && _renumber_generators!(automorphism_buffer().generators, canonperm, inverse, scratch)
    _renumber_orbits!(orbits, canonperm, inverse, scratch)
    return
end

# an automorphism `a` becomes `k -> inverse[a[canonperm[k]]]`
function _renumber_generators!(gens, canonperm, inverse, scratch)
    for generator in gens
        copyto!(scratch, generator)
        for k in eachindex(generator)
            generator[k] = inverse[scratch[canonperm[k]]]
        end
    end
    return
end

function _renumber_orbits!(orbits, canonperm, inverse, scratch)
    copyto!(scratch, orbits)
    for k in eachindex(orbits)
        orbits[k] = inverse[scratch[canonperm[k]]]
    end
    # the old label is the smallest vertex of its orbit in the old numbering, which need not be the
    # smallest in the new one, so it only identifies the orbit here and has to be minimized again
    fill!(scratch, zero(eltype(scratch)))
    for k in eachindex(orbits)
        iszero(scratch[orbits[k]]) && (scratch[orbits[k]] = k)
    end
    for k in eachindex(orbits)
        orbits[k] = scratch[orbits[k]]
    end
    return
end

"""
    nauty(g::AbstractNautyGraph; canonize=false, options...)
    nauty(g::AbstractNautyGraph, options::NautyOptions; canonize=false)

Compute a graph `g`'s canonical permutation and [`AutomorphismGroup`](@ref). If `canonize=true`,
`g` will additionally be canonized in-place.

Every keyword other than `canonize` is passed on to [`NautyOptions`](@ref), so `generators`,
`exact_order`, `digraph_or_loops` and `ignorelabels` can all be set here. Passing a `NautyOptions`
instead requests whatever it was built with.

The orbits and an approximate group order come for free with every run. The generators and the
exact group order each cost an extra callback into Julia, so they have to be requested.

!!! warning "`canonize` renumbers the group as well"

    Nauty reports the automorphism group in terms of `g`'s vertex numbering on input. With
    `canonize=true` that numbering is replaced, so the returned orbits and generators are rewritten
    to match the canonized `g` and do *not* refer to the graph that was passed in.

See also [`automorphism_group`](@ref) for the automorphism group on its own, and [`canonize!`](@ref)
and [`canonical_permutation`](@ref) for other tools related to canonization.
"""
function nauty end

function nauty(g::AbstractNautyGraph; canonize=false, options...)
    # the two collecting options are read back out because the group is built here; their names are
    # part of `options`' type, so this stays as inferable as spelling them out would be
    generators = get(values(options), :generators, false)
    exact_order = get(values(options), :exact_order, false)

    canonperm, orbits, statistics = _nauty(g, NautyOptions(g; options...), canonize)
    canonize && _recanonize!(orbits, canonperm, generators)
    return canonperm, _automorphism_group(statistics, orbits, generators, exact_order)
end

function nauty(g::AbstractNautyGraph, options::NautyOptions; canonize=false)
    generators = options.userautomproc != C_NULL
    canonperm, orbits, statistics = _nauty(g, options, canonize)
    canonize && _recanonize!(orbits, canonperm, generators)
    return canonperm, _automorphism_group(statistics, orbits,
            generators, options.userlevelproc != C_NULL)
end

# Everything `nauty` does apart from building the `AutomorphismGroup`, which its callers assemble
# themselves so that the keyword method can fold its flags away and infer a concrete type.
function _nauty(g::AbstractNautyGraph, options::NautyOptions, canonize)
    if is_directed(g) && !isone(options.digraph)
        throw(ArgumentError("Nauty options need to match the directedness of the input graph. Make sure to instantiate options with `digraph=true` if the input graph is directed."))
    end
    if !isone(options.getcanon)
        # Right now, all implemented functionality is based on computing the canonical form, so it makes no sense to run nauty without computing it.
        throw(ArgumentError("`options.getcanon` needs to be enabled."))
    end

    canong, canonperm, orbits, statistics = _canonical_form(g, options)
    orbits .+= 1 # nauty counts vertices from zero

    if canonize
        _copycanon!(g, canong, canonperm)
        g.iscanon = true
    end

    # free memory allocated by nauty for sparse graphs
    canong isa SparseGraphRep && _free_sparsegraphrep(canong)
    return canonperm, orbits, statistics
end

function _canonical_form(g::AbstractNautyGraph, options::NautyOptions=NautyOptions(g), statistics::NautyStatistics=dump_statistics())
    # TODO: allow the user to pass pre-allocated arrays for lab, ptn, orbits, canong in a safe way.
    lab, ptn = vertexlabels2labptn(labels(g))
    orbits = zeros(Cint, nv(g))
    canong = if g isa DenseNautyGraph 
        Graphset{wordtype(g)}(g.graphset.n, g.graphset.m)
    else
        SparseGraphRep()
    end

    collecting = has_automorphism_callbacks(options)
    collecting && _reset_automorphism_buffer!()
    _ccall_nauty(g, lab, ptn, orbits, options, statistics, canong)
    collecting && _check_automorphism_buffer()

    # nauty counts vertices from zero. `orbits` is left as it is, because only `nauty` reports it
    # and most callers here discard it.
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
    automorphism_group(g::AbstractNautyGraph)

Return the [`AutomorphismGroup`](@ref) of `g`, containing the exact order, vertex orbits, and generators.

Use [`nauty`](@ref) instead to also get the canonical permutation, or to skip the parts of the
computation you do not need.
"""
automorphism_group(g::AbstractNautyGraph) = nauty(g; generators=true, exact_order=true)[2]

@inline function _automorphism_group(statistics::NautyStatistics, orbits, generators, exact_order)
    # nauty splits the order into a mantissa and a power of ten to keep it in range
    approximate = statistics.grpsize1 * exp10(statistics.grpsize2)
    # the common case touches neither the buffer nor task-local storage
    generators || exact_order || return AutomorphismGroup(approximate, orbits, nothing)

    buffer = automorphism_buffer()
    return AutomorphismGroup(exact_order ? prod(big, buffer.levelindices; init=big(1)) : approximate,
            orbits, generators ? buffer.generators : nothing)
end

"""
    canonize!(g::AbstractNautyGraph)

Reorder `g`'s vertices into canonical order and return the permutation used.

See also [`nauty`](@ref) and [`canonical_permutation`](@ref) for other tools related to canonization.
"""
function canonize! end

function canonize!(g::AbstractNautyGraph)
    iscanon(g) && return canonical_permutation(g)
    canong, canonperm, _ = _canonical_form(g)
    _copycanon!(g, canong, canonperm)
    canong isa SparseGraphRep && _free_sparsegraphrep(canong)
    return canonperm
end

"""
    canonical(g::AbstractNautyGraph)

Return a canonized copy of `g` together with the canonical permutation, leaving `g` untouched.

See also [`canonize!`](@ref), which canonizes in place and returns only the permutation.
"""
function canonical end

function canonical(g::AbstractNautyGraph)
    h = copy(g)
    return h, canonize!(h)
end

function canonical(g::DenseNautyGraph{D,W}) where {D,W}
    iscanon(g) && return copy(g), collect(Cint(1):Cint(nv(g)))
    canong, canonperm, _ = _canonical_form(g)
    # `canong` is allocated fresh by nauty, so the new graph can take it over instead of copying.
    return DenseNautyGraph{D,W}(canong, g._labels[canonperm], g.ne, true), canonperm
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
    canong, canonperm, _ = _canonical_form(g)
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
    canong, permg, _ = _canonical_form(g)
    canonh, permh, _ = _canonical_form(h)
    isiso = canong == canonh && view(g._labels, permg) == view(h._labels, permh)
    
    return isiso
end

function is_isomorphic(g::SparseNautyGraph, h::SparseNautyGraph)
    iscanon(g) && iscanon(h) && return g == h
    canong, permg, _ = _canonical_form(g)
    canonh, permh, _ = _canonical_form(h)
    isiso = canong == canonh && view(g._labels, permg) == view(h._labels, permh)

    _free_sparsegraphrep(canong)
    _free_sparsegraphrep(canonh)
    return isiso
end
≃(g::AbstractNautyGraph, h::AbstractNautyGraph) = is_isomorphic(g, h)

"""
    canonical_id(g::AbstractNautyGraph)

Hash the canonical version of `g`, using the first 128 bits returned by the SHA256 algorithm.

`is_isomorphic(g1, g2)` implies `canonical_id(g1) == canonical_id(g2)`, so differing ids prove that `g1` and `g2` are not isomorphic.
Equal ids imply isomorphism only up to hash collisions.

!!! note

    `canonical_id` computes different results depending on whether the input is a dense `NautyGraph` or sparse `SpNautyGraph`, meaning that different graph
    types _cannot_ be compared using their canonical ids.

"""
function canonical_id(::AbstractNautyGraph) end

function canonical_id(g::DenseNautyGraph)
    if iscanon(g)
        return _SHAhash(g.graphset, g._labels)
    else
        canong, canonperm, _ = _canonical_form(g)
        return _SHAhash(canong, @view g._labels[canonperm])
    end
end

function canonical_id(g::SparseNautyGraph)
    # needs to work for 0 vertices
    if iscanon(g)
        sortlists!(g)
        return _SHAhash_adjacency(g, g._labels)
    else
        canong, canonperm, _ = _canonical_form(g)
        sortlists!(canong)
        h = _SHAhash_adjacency(canong, @view g._labels[canonperm])
        _free_sparsegraphrep(canong)
        return h
    end
end

# Hash the bytes of `x` in little-endian order, without copying it into a buffer first.
# Both conditions are compile-time constants, so the byte swap is only ever compiled on a
# big-endian host, where it is not performance critical.
@inline function _shaupdate!(ctx, x::AbstractArray)
    isempty(x) && return ctx
    y = ENDIAN_BOM == 0x04030201 || sizeof(eltype(x)) == 1 ? x : map(htol, x)
    SHA.update!(ctx, vec(reinterpret(UInt8, y)))
    return ctx
end
# Hash the packed words rather than the `n^2` entries of the matrix.
# `m` can exceed the minimum after vertex removals, so the padding words have to be dropped.
_shaupdate!(ctx, gs::Graphset) = _shaupdate!(ctx, _maybe_copy_active_words(gs))

_digest(ctx) = reinterpret(UInt128, SHA.digest!(ctx))[1]

function _SHAhash(xs...)
    ctx = SHA.SHA256_CTX()
    foreach(x -> _shaupdate!(ctx, x), xs)
    return _digest(ctx)
end

# Splatting the adjacency lists into `_SHAhash` would make the argument count depend on `nv`.
function _SHAhash_adjacency(sg, labels)
    if length(labels) != sg.nv
        throw(ArgumentError("got $(length(labels)) labels for a graph on $(sg.nv) vertices"))
    end
    ctx = SHA.SHA256_CTX()
    for i in Base.OneTo(sg.nv)
        _shaupdate!(ctx, _fadj_0based(sg, i))
    end
    _shaupdate!(ctx, labels)
    return _digest(ctx)
end
