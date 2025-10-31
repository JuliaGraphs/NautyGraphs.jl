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
```julia
using NautyGraphs, Graphs

A = [0 1 0 0;
     1 0 1 1;
     0 1 0 1;
     0 1 1 0]
g = NautyGraph(A)

h = NautyGraph(4)
for edge in [(2, 4), (4, 1), (4, 3), (1, 3)]
  add_edge!(h, edge)
end
```
Internally, a `NautyGraph` is represented as a bit vector, so that it can be passed directly to _nauty_ without any conversion.
To check whether two graphs are isomorphic, use `is_isomorphic` or `≃` (`\simeq`):
```julia-repl
julia> g ≃ h
true

julia> adjacency_matrix(g) == adjacency_matrix(h)
false
```
Use `canonize!(g)` to reorder `g` into canonical order. `canonize!(g)` also returns the permutation needed to canonize `g`:
```julia-repl
julia> canonize!(g)
[1, 3, 4, 2]

julia> canonize!(h)
[2, 1, 3, 4]

julia> adjacency_matrix(g) == adjacency_matrix(h)
true
```
Isomorphisms can also be computed by comparing hashes. `ghash(g)` computes the canonical representative of a graph's isomorphism class and then hashes the canonical adjacency matrix and vertex labels.
```julia-repl
julia> ghash(g)
0x3127d9b726f2c846
julia> ghash(h)
0x3127d9b726f2c846
```
Graph hashes make it possible to quickly compare large numbers of graphs for isomorphism. Simply compute all hashes and filter out the duplicates!

To obtain information about a graph's automorphism group, use `nauty(g)`. This will return the canonical permutation as well as an `AutomorphismGroup` object.
Right now, the recorded properties of the automorphism group are very limited and only include the group size and orbits, but this will change in the future.

## See also
- [_nauty_ & _traces_](https://pallini.di.uniroma1.it/)
- [Nauty.jl](https://github.com/bovine3dom/Nauty.jl)
- [NautyTraces.jl](https://github.com/laurentbartholdi/NautyTraces.jl)
- [Graphs.jl](https://github.com/JuliaGraphs/Graphs.jl)
