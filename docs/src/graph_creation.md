# Creating and modifying Graphs
NautyGraphs.jl defines the `NautyGraph` or `NautyDiGraph` graph formats, which can be created and modified following the Graphs.jl API.
Under the hood, a `NautyGraph` is represented by an adjacency matrix, following the format specified by _nauty_[^1]. Because `NautyGraph`s
are intrinsically compatible with _nauty_, performing isomorphism checks or graph canonization can be done without any conversion overhead.

### Creating `NautyGraphs`
`NautyGraphs` and `NautyDiGraphs` can be created in the same way as graphs from `Graphs.jl`.  As an example, here are three different ways to define the same graph:

```jldoctest default
using NautyGraphs

A = [0 1 0 0;
     1 0 1 1;
     0 1 0 1;
     0 1 1 0]

g1 = NautyGraph(A)

edges = [Edge(1, 2), Edge(2, 3), Edge(2, 4), Edge(3, 4)]

g2 = NautyGraph(4)
for e in edges
  add_edge!(g2, e)
end

g3 = NautyGraph(edges)

g1 == g2 == g3

# output
true
```
TODO: conversion from and to regular graphs!!

### Setting vertex labels

There is one difference to `Graphs.jl`, in that `NautyGraphs` are inherently __labeled__, meaning that every vertex carries and integer label.
If labels are not explicitly provided, they are set to zero. Here is an example that sets vertex labels during graph creation:

```jldoctest default
julia> g4 = NautyGraph(edges; vertex_labels=[4, 3, 2, 1])
{4, 4} undirected NautyGraph

julia> labels(g4)
4-element Vector{Int64}:
 4
 3
 2
 1
```

### Adding or removing vertices and edges
Modify a graph after creation can also be done using Graphs.jl functions. Here is a quick example:
```jldoctest default; output=false

g5 = NautyDiGraph(4; vertex_labels=[0, 5, 20, 8])

add_edge!(g5, 1, 2)
add_edge!(g5, Edge(3, 4))

# Vertex lables here are optional, the default is zero.
add_vertex!(g5; vertex_label=42) # note the singular "vertex_label"
add_vertices!(g5, 3; vertex_labels=[7, 7, 7]) # note the plural "vertex_labels"

rem_edge!(g5, Edge(1, 2))
rem_edge!(g5, 3, 4)

rem_vertex!(g5, 8) # removes vertex 8
rem_vertices!(g5, [1, 3, 5]) # removes vertices 1, 3, and 5

# output
true
```

### Edge labeled graphs
NautyGraphs.jl does not support edge labels. However, it is possible to manually represent any edge-labeled graph as a (larger)
vertex labeled graph. See, for example, Section 14 of the [nauty manual](https://pallini.di.uniroma1.it/Guide.html) for more information.

[^1]: If you are interested in the details of the low-level graph representation, check out the [nauty manual](https://pallini.di.uniroma1.it/Guide.html).