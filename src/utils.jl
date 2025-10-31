function vertexlabels2labptn(labels::Vector{<:Integer})
    n = length(labels)
    lab = zeros(Cint, n)
    ptn = zeros(Cint, n)
    return vertexlabels2labptn!(lab, ptn, labels)
end
function vertexlabels2labptn!(lab::Vector{<:Integer}, ptn::Vector{<:Integer}, labels::Vector{<:Integer})
    lab .= 1:length(labels)
    sort!(lab, alg=QuickSort, by=k->labels[k])
    @views lab .-= 1

    for i in 1:length(lab)-1
        ptn[i] = ifelse(labels[lab[i+1]+1] == labels[lab[i]+1], 1, 0)
    end
    return lab, ptn
end