using Pkg; Pkg.add("Graphs")

using Documenter, NautyGraphs

DocMeta.setdocmeta!(NautyGraphs, :DocTestSetup, :(using NautyGraphs, Graphs); recursive=true)

makedocs(sitename="NautyGraphs.jl")
deploydocs(repo="github.com/JuliaGraphs/NautyGraphs.jl.git")