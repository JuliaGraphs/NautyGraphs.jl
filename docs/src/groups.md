# Graph automorphism groups

Use `automorphism_group(g)` to get a graph's [`AutomorphismGroup`](@ref).
It reports the group's [`order`](@ref), its vertex [`orbits`](@ref) and a set of [`generators`](@ref).

```jldoctest groups
julia> using NautyGraphs, Graphs

julia> g = NautyGraph(smallgraph(:petersen));

julia> autg = automorphism_group(g)
AutomorphismGroup
  order       120
  vertices    10
  orbits      1
  generators  4

julia> order(autg)
120

julia> orbit_partition(autg)
1-element Vector{Vector{Int64}}:
 [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
```

Generators are permutations in one-based form: generator `p` maps vertex `i` to `p[i]`.
Together they generate the whole group, so its `order` is generally much larger than the number of generators.

The identity belongs to every automorphism group and is never listed as a generator.
A graph with no symmetry therefore comes back with an empty generating set, not with a single identity permutation.

```jldoctest groups
julia> frucht = automorphism_group(NautyGraph(smallgraph(:frucht)))
AutomorphismGroup
  order       1
  vertices    12
  orbits      12
  generators  0

julia> generators(frucht)
Vector{Int64}[]
```


`orbits(autg)` labels every vertex with the smallest vertex it can be mapped to, so two vertices share an orbit exactly if they carry the same label.
`orbit_partition(autg)` turns that labelling into one vector per orbit, at the cost of an allocation per orbit.

## Computing less

`automorphism_group` computes everything nauty can report.
When that is more than you need, call [`nauty`](@ref) directly and switch the expensive parts off.
It returns the canonical permutation alongside the group, so nothing has to be recomputed:

```jldoctest groups
julia> canonperm, autg = nauty(g; generators=true);

julia> order(autg)
120.0
```

The orbits and an approximate order come for free with every run.
The generators and the exact order each cost an extra callback into Julia, so they are opt-in:

| keyword | what it adds | cost |
| --- | --- | --- |
| none | orbits, `order` as a `Float64` | free |
| `generators=true` | the generating permutations | one callback per generator |
| `exact_order=true` | `order` as an exact `BigInt` | one callback per search-tree level |
| `canonize=true` | canonizes `g` in place | rewrites the group into the new numbering |

Without `exact_order=true`, `order(autg)` is a `Float64`: it carries about 16 significant digits, is exact up to roughly `10^12`, and overflows to `Inf` past `10^308`.
Ask for the exact order whenever you need to count with it, for example when dividing by ``|\mathrm{Aut}(g)|``.

!!! warning "`canonize` renumbers the group as well"

    Nauty reports the automorphism group in terms of `g`'s vertex numbering on input.
    With `canonize=true` that numbering is replaced, so the returned orbits and generators are rewritten to match the canonized `g` and no longer refer to the graph as it was passed in.

## Working with the group

NautyGraphs deliberately does not implement group theory beyond what nauty reports.
To enumerate elements, test membership or build stabilizer chains, hand the generators to a group theory package:

```julia
using PermutationGroups
group = PermGroup([Perm(p) for p in generators(autg)])
```
