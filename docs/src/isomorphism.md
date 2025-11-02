# Graph isomorphisms and canonization
The [graph isomorphism problem]((https://en.wikipedia.org/wiki/Graph_isomorphism_problem)) is determining whether two different-looking graphs can be made identical by relabeling their vertices. If such a relabeling exists, the two graphs are said to be _isomorphic_ to each other, and for many purposes can be thought of as essentially the same graph. Determining if two graphs are isomorphic is a challenging problem, and no universally fast algorithm exists. However, in practice, checking for isomorphism is often efficient, particularly for smaller graphs. 

The purpose of NautyGraphs.jl is to make isomorphsim checking fast and convenient from within Julia and the Graphs.jl ecosystem. For this, NautyGraphs.jl provides convenient access to [_nauty_](https://pallini.di.uniroma1.it), one of the most established libraries for graph isomorphism and canonization.

## Graph canonization
The _nauty_ library actually does not solve the graph isomorphsim problem directly, but instead solves a related, but more general, problem called __graph canonization__: Given any graph, nauty can compute its _canonical form_, which is a special relabeling (permutation) of the graph's vertices. What makes the canonical form special is that __any isomorphic graphs have the same canonical form__. This means that the isomorphism check between two graphs becomes a simple equality check between their canonical forms.

To see what this looks like in practice, let's first construct two unequal, but isomorphic graphs:
```jldoctest
g1 = NautyGraph([Edge(1, 2), Edge(2, 3), Edge(2, 4), Edge(3, 4)])
g2 = g1[[3, 2, 4, 1]] # permute the vertices of g1

g1 == g2

# output
false
```
We can now canonize both graphs using the `canonize!` function. This will canonize the graphs in-place and return the permutation that was applied (this is useful if external graph metadata needs to be kept in sync).
```jldoctest
julia> canonize!(g1)
4-element Vector{Int32}:
 1
 3
 4
 2

julia> canonize!(g2)
4-element Vector{Int32}:
 4
 1
 3
 2
```

Now that both graphs are in canonical form, we can verify that the graphs are indeed isomorphic by checking them for equality:
```jldoctest
g1 == g2
# output
true
```

Besides `canonize!`, NautyGraphs.jl also provides some more utility functions for canonization, see the API for more details.

## Graph isomorphism
In many cases, we are not interested in the canonical form of a graph, but only want to determine if two graphs are isomorphic. NautyGraph.jl provides the `is_isomorphic` function (infix version: `≃`, `\simeq`) that checks for isomorphism by comparing canonical forms, without modifying the input graphs:
```jldoctest
g3 = NautyGraph([Edge(1, 5), Edge(3, 4), Edge(4, 1), Edge(2, 1)])
g4 = g3[[3, 2, 4, 1, 5]] # permute the vertices of g3

g1 == g2, g1 ≃ g2

# output
false, true
```

## Filtering graphs by isomorphism class
A common situation is removing isomorphic graphs from a collection. In principle, this could be done by iteratively comparing all pairs of graphs for isomorphism, but this is slow and inefficient ($O(n^2)$). By combining graph canonization with a simple hash table, we can speed this up dramatically (make it $O(n)$).
In practice, all we need to do is canonize all graphs we want to filter, and them push them to a `Set`, as in this example:

```jldoctest
gs = [NautyGraph(5), NautyGraph(5), NautyGraph(6)]
add_edge!(gs[1], 1, 2)
add_edge!(gs[2], 2, 3)
# gs[1] and gs[2] are isomorphic!

foreach(canonize!, gs)

s = Set(gs)
# output
Set{NautyGraph{UInt64}} with 2 elements:
  {5, 1} undirected NautyGraph
  {6, 0} undirected NautyGraph
```

The resulting `Set` will then only contain one graph per isomorphism class.

## Graph hashing & canonical ID
Under the hood, the `Set`-based approach described above determines isomorphisms by compared the __hashes__ of the 
canonized graphs, and falling back to equality checks if a hash collision is found. When doing this manually, great care is needed, because using `Base.hash` for graph hashing is __not crpytographically__ secure. In fact, once more than a few thousand graphs are to be compared, __hash collisions should be expected!__

If you want to compare graph hashes without checking for collisions, it is strongly recommended to hash graphs using the `canonical_id` function, with returns the first 128 bits of
the cryptographically secure SHA256 hash algorithm. This should provide sufficient collision resistance for most applications.