# NautyGraphs.jl


[![Build Status](https://github.com/mxhbl/NautyGraphs.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/mxhbl/NautyGraphs.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/mxhbl/NautyGraphs.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/mxhbl/NautyGraphs.jl)

NautyGraphs.jl is a Julia interface to [_nauty_](https://pallini.di.uniroma1.it/) by Brendan McKay. It allows for efficient isomorphism checking, canonical labeling, and hashing of vertex-labeled graphs. In addition, NautyGraphs.jl is fully compatible with the [Graphs.jl](https://github.com/JuliaGraphs/Graphs.jl) API. This makes it easy to create or modify graphs through familiar syntax, and allows NautyGraphs to work with a large library of graph algorithms.
**Warning**: NautyGraph.jl currently does not work on Windows. This will be hopefully be fixed soon.
## Installation
To install NautyGraphs.jl from the Julia REPL, enter `]` to enter Pkg mode, and then run
```
pkg> add https://github.com/mxhbl/NautyGraphs.jl
```
## Basic Usage
NautyGraphs.jl defines the `NautyGraph` or `NautyDiGraph` graph formats, which can be constructed and modified in the same way as regular `Graphs` from Graphs.jl:
```
using NautyGraphs, Graphs

A = [0 1 0 0;
     1 0 1 1;
     0 1 0 1;
     0 1 1 0]
g = NautyGraph(A)

h = NautyGraph(4)
for edge in [(2, 4), (4, 1), (4, 3), (1, 3)]
  add_edge!(h, edge...)
end
```
Internally, a `NautyGraph` is represented as a bit vector, so that it can be passed directly to _nauty_ without any conversion.
To check whether two graphs are isomorphic, use `is_isomorphic` or `≃` (`\simeq`):
```
julia> g ≃ h
true

julia> adjacency_matrix(g) == adjacency_matrix(h)
false
```
Use `canonize!(g)` to reorder `g` into canonical order. `canonize!(g)` also returns the permutation needed to canonize `g`, as well as the size of its automorphism group:
```
julia> canonize!(g)
([1, 3, 4, 2], 2)

julia> canonize!(h)
([2, 1, 3, 4], 2)

julia> adjacency_matrix(g) == adjacency_matrix(h)
true
```
Isomorphisms are computed by comparing hashes. `hash(g)` computes the canonical representative of a graph's isomorphism class and then hashes the canonical adjacency matrix and vertex labels.
```
julia> hash(g)
0x3127d9b726f2c846
julia> hash(h)
0x3127d9b726f2c846
```
Using hashes makes it possible to quickly compare large numbers of graphs for isomorphism. Simply compute all graph hashes and filter out the duplicates!
