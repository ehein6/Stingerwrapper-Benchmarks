using LightGraphs
using StingerWrapper
using BenchmarkTools
using JLD
import Base.Threads: nthreads

include("lgparallelbfs.jl")

function setupgraph(
    scale::Int64,
    edgefactor::Int64;
    a::Float64=0.57,
    b::Float64=0.19,
    c::Float64 = 0.19
    )
    srand(0)
    #TODO: Replace with reading from disk
    #graph = kronecker(scale, edgefactor, a=a, b=b, c=c)
    g = DiGraph(2^scale)
    curdir = dirname(@__FILE__)
    inputfile = joinpath(curdir, "input", "kron_$(scale)_$(edgefactor).graph.el")
    open(inputfile) do f
        for line in eachline(f)
            vals = split(line)
            add_edge!(g, parse(Int64, vals[1])+1, parse(Int64, vals[2])+1)
        end
    end
    g
end

function bfsvisitorbenchutil(g::SimpleGraph, nv::Int64)
    visitor = LightGraphs.TreeBFSVisitorVector(zeros(Int,nv))
    for i in 1:1001
        LightGraphs.bfs_tree!(visitor, g, i)
    end
end

function serialbfsbenchutil(g::SimpleGraph, nv::Int64)
    for i in 1:1001
        bfs(NaiveSerialBFS(), g, i, nv)
    end
end

function levelsyncbfsbenchutil(g::SimpleGraph, nv::Int64)
    for i in 1:1001
        bfs(LevelSynchronous(), g, i, nv)
    end
end

function lg_bench(
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
    info("Running BFS benchmark for LG with threads = $threads, scale = $scale, edgefactor = $edgefactor")
    bfs_trial = run(bfs_bench)
    @show minimum(bfs_trial)
    jldopen(filename, "w") do f
        write(f, "bfs_trial", bfs_trial)
    end
    bfs_trial
end

function lg_visitor_bench(
    scale::Int64,
    edgefactor::Int64,
    filename;
    a::Float64=0.57,
    b::Float64=0.19,
    c::Float64 = 0.19,
    )
    nv = 2^scale
    threads = nthreads()
    lg_bfs_bench = @benchmarkable bfsvisitorbenchutil(g, $nv) seconds=6000 samples=3 setup=(g=setupgraph($scale, $edgefactor))
    info("Running BFS benchmark for visitor LG with threads = $threads, scale = $scale, edgefactor = $edgefactor")
    visitor_trial = run(lg_bfs_bench)
    @show minimum(visitor_trial)
    curdir = dirname(@__FILE__)
    jldopen(joinpath(curdir, "output", "lg", "lg_visitor_$(scale)_$(edgefactor).jld"), "w") do f
        write(f, "bfs_trial", visitor_trial)
    end
end
