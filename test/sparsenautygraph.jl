using NautyGraphs

ll = NautyGraphs.nauty_jll.libnauty

a = SparseNautyGraph{false}(3)
a.d = [2, 1, 1, 0, 0]
a.nv = 3
a.nde = 4
a.v = [0, 3, 5]
a.e = [2, 1, 0, 0, 0, 0, 0]

b = SparseGraphRep(3)
b.d = [2, 1, 1, 0, 0]
b.nv = 3
b.nde = 4
b.v = [0, 4, 6]
b.e = [1, 2, 0, 0, 0, 0, 0, 0]


c = C_NULL

@ccall ll.sortlists_sg(Ref(a)::Ref{SparseGraphGraphRep})::Cvoid
@ccall ll.aresame_sg(Ref(a)::Ref{SparseGraphGraphRep}, Ref(b)::Ref{SparseGraphGraphRep})::Cint