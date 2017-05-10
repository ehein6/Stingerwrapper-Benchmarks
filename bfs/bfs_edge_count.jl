using StingerWrapper

function setupgraph(
    scale::Int64,
    edgefactor::Int64;
    a::Float64=0.57,
    b::Float64=0.19,
    c::Float64 = 0.19
    )
    s = Stinger(generateconfig(2^scale))
    curdir = dirname(@__FILE__)
    inputfile = joinpath(curdir, "input", "kron_$(scale)_$(edgefactor).graph.el")
    edges = readdlm(inputfile, Int64)
    #dyno_set_initial_edges!(s, edges)
    for i=1:size(edges, 1)
        insert_edge!(s, 0, edges[i, 1], edges[i, 2], 0, 0)
    end
    return s
end

function getsources!(sources::Vector{Int64}, scale::Int64, edgefactor::Int64)
    curdir = dirname(@__FILE__)
    inputfile = joinpath(curdir, "input", "bfssources_$(scale)_$(edgefactor)")
    open(inputfile) do f
        for (idx, line) in enumerate(eachline(f))
            vals = split(line)
            sources[idx] = parse(Int64, vals[1])
        end
    end
    nothing
end


function count_edges(scale::Int64)
    nv = 2^scale
    sources = zeros(Int64, 64)
    getsources!(sources, scale, 16)
    @show sources
    s = setupgraph(scale, 16)
    outdegrees = zeros(Int64, nv)
    for i=1:nv
        outdegrees[i] = outdegree(s, i)
    end
    edgecount = 0
    for src in sources
        parents = bfs(LevelSynchronous(), s, src, nv)
        edgecount+=sum(map(x->outdegrees[x], find(x->x!=-2, parents)))
    end
    edgecount
end
