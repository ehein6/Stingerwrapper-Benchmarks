using StingerWrapper
using BenchmarkTools
using JLD
import Base.Threads: nthreads

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
    open(inputfile) do f
        for line in eachline(f)
            vals = split(line)
            insert_edge!(s, 0, parse(Int64, vals[1]), parse(Int64, vals[2]), 1, 1)
        end
    end
    return s
end

function serialbfsbenchutil(s::Stinger, nv::Int64, sources::Vector{Int64})
    for src in sources
        bfs(s, src, nv)
    end
end

function levelsyncbfsbenchutil(s::Stinger, nv::Int64, sources::Vector{Int64})
    for src in sources
        bfs(LevelSynchronous(), s, src, nv)
    end
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

function stingerwrapper_bench(
    scale::Int64,
    edgefactor::Int64,
    filename;
    a::Float64=0.57,
    b::Float64=0.19,
    c::Float64 = 0.19,
    )
    nv = 2^scale
    threads = nthreads()
    sources = zeros(Int64, 64)
    getsources!(sources, scale, edgefactor)
    @show sources
    if threads==1
        bfs_bench = @benchmarkable serialbfsbenchutil(s, $nv, $sources) seconds=6000 samples=3 setup=(s=setupgraph($scale, $edgefactor))
    else
        bfs_bench = @benchmarkable levelsyncbfsbenchutil(s, $nv, $sources) seconds=6000 samples=3 setup=(s=setupgraph($scale, $edgefactor))
    end
    info("Running BFS benchmark for StingerWrapper with threads = $threads, scale = $scale, edgefactor = $edgefactor")
    bfs_trial = run(bfs_bench)
    @show minimum(bfs_trial)
    jldopen(filename, "w") do f
        write(f, "bfs_trial", bfs_trial)
    end
end
