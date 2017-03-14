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
    srand(0)
    #TODO: Replace with reading from disk
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

function serialbfsbenchutil(s::Stinger, nv::Int64)
    for i in 0:1000
        bfs(s, i, nv)
    end
end

function levelsyncbfsbenchutil(s::Stinger, nv::Int64)
    for i in 0:1000
        bfs(LevelSynchronous(),s, i, nv)
    end
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
    if threads==1
        bfs_bench = @benchmarkable serialbfsbenchutil(s, $nv) seconds=6000 samples=3 setup=(s=setupgraph($scale, $edgefactor))
    else
        bfs_bench = @benchmarkable levelsyncbfsbenchutil(s, $nv) seconds=6000 samples=3 setup=(s=setupgraph($scale, $edgefactor))
    end
    info("Running BFS benchmark for StingerWrapper with threads = $threads, scale = $scale, edgefactor = $edgefactor")
    bfs_trial = run(bfs_bench)
    @show minimum(bfs_trial)
    jldopen(filename, "w") do f
        write(f, "bfs_trial", bfs_trial)
    end
end
