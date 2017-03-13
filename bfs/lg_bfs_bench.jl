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
    graph = kronecker(scale, edgefactor, a=a, b=b, c=c)
    g = DiGraph(2^scale)
    for i in 1:size(graph, 2)
        add_edge!(g, graph[1, i]+1, graph[2, i]+1)
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
    if threads == 1
        lg_bfs_bench = @benchmarkable bfsvisitorbenchutil(g, $nv) seconds=6000 samples=3 setup=(g=setupgraph($scale, $edgefactor))
        visitor_trial = run(lg_bfs_bench)
        @show minimum(visitor_trial)
        curdir = dirname(@__FILE__)
        jldopen(joinpath(curdir, "output", "lg", "lg_visitor_$(scale)_$(edgefactor).jld"), "w") do f
            write(f, "bfs_trial", visitor_trial)
        end
    end
    bfs_trial
end
