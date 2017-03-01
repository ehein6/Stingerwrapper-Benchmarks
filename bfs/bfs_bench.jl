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
    graph = kronecker(scale, edgefactor, a=a, b=b, c=c)
    s = Stinger()
    for i in 1:size(graph, 2)
        insert_edge!(s, 0, graph[1, i], graph[2, i], 1, 1)
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

function bench(
    scale::Int64,
    edgefactor::Int64;
    a::Float64=0.57,
    b::Float64=0.19,
    c::Float64 = 0.19,
    filename::String="bfs_bench.jld"
    )
    nv = 2^scale
    threads = nthreads()
    if threads==1
        bfs_bench = @benchmarkable serialbfsbenchutil(s, $nv) seconds=6000 samples=3 setup=(s=setupgraph($scale, $edgefactor))
    else
        bfs_bench = @benchmarkable levelsyncbfsbenchutil(s, $nv) seconds=6000 samples=3 setup=(s=setupgraph($scale, $edgefactor))
    end
    info("Running BFS benchmark with threads = $threads, scale = $scale, edgefactor = $edgefactor")
    bfs_trial = run(bfs_bench)
    @show minimum(bfs_trial)
    bfs_trial
end

function benchgroup(
        scales::Range{Int64},
        edgefactor::Int64;
        a::Float64=0.57,
        b::Float64=0.19,
        c::Float64 = 0.19,
    )
    threads = nthreads()
    jldopen("threads_bfs_$threads.jld", "w") do f
        for scale in scales
            bfs_trial = bench(scale, edgefactor, a=a, b=b, c=c)
            write(f, "bfs_trial_$(scale)_$(edgefactor)", bfs_trial)
        end
    end
end

benchgroup(10:20, 16)
