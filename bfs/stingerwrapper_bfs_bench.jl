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
