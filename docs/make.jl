using Pkg; Pkg.add("Graphs")

using Documenter, NautyGraphs

DocMeta.setdocmeta!(NautyGraphs, :DocTestSetup, :(using NautyGraphs, Graphs); recursive=true)

makedocs(sitename="NautyGraphs.jl";
    pages = [
        "index.md",
        "Creating and modifying graphs" => "graph_creation.md",
        "Isomorphism and canonization" => "isomorphism.md",
        "Automorphism Groups" => "groups.md"]
        )
deploydocs(repo="github.com/JuliaGraphs/NautyGraphs.jl.git")