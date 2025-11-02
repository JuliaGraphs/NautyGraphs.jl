# NautyGraphs.jl

NautyGraphs.jl is a Julia interface to the popular graph isomorphism tool [_nauty_](https://pallini.di.uniroma1.it/) by Brendan McKay. It allows for efficient isomorphism checking, canonical labeling, and hashing of vertex-labeled graphs. In addition, NautyGraphs.jl is fully compatible with the [Graphs.jl](https://github.com/JuliaGraphs/Graphs.jl) API. This makes it easy to create or modify graphs through familiar syntax, and allows NautyGraphs to work with a large library of graph algorithms.
**Warning**: NautyGraphs.jl currently does not work on Windows.
## Installation
To install NautyGraphs.jl from the Julia REPL, press `]` to enter Pkg mode, and then run
```
pkg> add NautyGraphs
```
## Basic Usage
NautyGraphs.jl defines the `NautyGraph` or `NautyDiGraph` graph formats, which can be constructed and modified in the same way as regular `Graphs` from Graphs.jl:
```jldoctest intro; output=false
using NautyGraphs, Graphs

A = [0 1 0 0;
     1 0 1 1;
     0 1 0 1;
     0 1 1 0]
g = NautyGraph(A)

h = NautyGraph(4)
for edge in [Edge(2, 4), Edge(4, 1), Edge(4, 3), Edge(1, 3)]
  add_edge!(h, edge)
end
# output

```
Internally, a `NautyGraph` is represented as a bit vector, so that it can be passed directly to _nauty_ without any conversion.
To check whether two graphs are isomorphic, use `is_isomorphic` or `≃` (`\simeq`):
```jldoctest intro
julia> g == h
false

julia> g ≃ h
true
```
Use `canonize!(g)` to reorder `g` into canonical order. `canonize!(g)` also returns the permutation needed to canonize `g`:
```jldoctest intro
julia> canonize!(g)
4-element Vector{Int32}:
 1
 3
 4
 2

julia> canonize!(h)
4-element Vector{Int32}:
 2
 1
 3
 4

julia> g == h
true
```

## See also
- [_nauty_ & _traces_](https://pallini.di.uniroma1.it/)
- [Nauty.jl](https://github.com/bovine3dom/Nauty.jl)
- [NautyTraces.jl](https://github.com/laurentbartholdi/NautyTraces.jl)
- [Graphs.jl](https://github.com/JuliaGraphs/Graphs.jl)
