import Graphs.Experimental: has_isomorph, count_isomorph

export NautyAlg, has_isomorph, count_isomorph

struct NautyAlg{S}
    NautyAlg(; sparse=false) = new{sparse}()
end

"""Lists all functions for which a `NautyAlg` method is defined"""
function nautyalg_methods()
    filter(names(@__MODULE__)) do s
        f = getproperty(@__MODULE__, s)
        f isa Function || return false
        any(methods(f)) do m
            sig = m.sig
            while sig isa UnionAll; sig = sig.body; end
            any(sig.parameters) do t
                t isa Type && t <: NautyAlg
            end
        end
    end
end

function has_isomorph(g1::AbstractGraph, g2::AbstractGraph, ::NautyAlg{false}; vertex_labels=(nothing, nothing))
    g1, g2 = DenseNautyGraph(g1; vertex_labels=vertex_labels[1]), DenseNautyGraph(g2;  vertex_labels=vertex_labels[2])
    return NautyGraphs.is_isomorphic(g1, g2)
end
function has_isomorph(g1::AbstractGraph, g2::AbstractGraph, ::NautyAlg{true}; vertex_labels=(nothing, nothing))
    g1, g2 = SparseNautyGraph(g1; vertex_labels=vertex_labels[1]), SparseNautyGraph(g2; vertex_labels=vertex_labels[2])
    return NautyGraphs.is_isomorphic(g1, g2)
end

function count_isomorph(g1::AbstractGraph, g2::AbstractGraph, ::NautyAlg{false}; vertex_labels=(nothing, nothing))
    g1, g2 = DenseNautyGraph(g1; vertex_labels=vertex_labels[1]), DenseNautyGraph(g2;  vertex_labels=vertex_labels[2])
    return _count_isomorph(g1, g2)
end
function count_isomorph(g1::AbstractGraph, g2::AbstractGraph, ::NautyAlg{true}; vertex_labels=(nothing, nothing))
    g1, g2 = SparseNautyGraph(g1; vertex_labels=vertex_labels[1]), SparseNautyGraph(g2; vertex_labels=vertex_labels[2])
    return _count_isomorph(g1, g2)
end

function _count_isomorph(g1, g2)
    _, autg = nauty(g1; canonize=true)
    if g1 ≃ g2
        return autg.n
    else
        return zero(autg.n)
    end
end