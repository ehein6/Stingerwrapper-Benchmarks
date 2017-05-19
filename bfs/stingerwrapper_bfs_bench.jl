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
    inputfile = joinpath(curdir, "input", "kron_$(scale)_$(edgefactor).graph.bin")
    num_edges = Int64(stat(inputfile).size / 32)
    edges = read(inputfile, Int64, (4, num_edges))
    dyno_set_initial_edges!(s, edges)
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
    s = setupgraph(scale, edgefactor)
    if threads==1
        bfs_bench = @benchmarkable serialbfsbenchutil($s, $nv, $sources) seconds=6000 samples=3
    else
        bfs_bench = @benchmarkable levelsyncbfsbenchutil($s, $nv, $sources) seconds=6000 samples=3
    end
    info("Running BFS benchmark for StingerWrapper with threads = $threads, scale = $scale, edgefactor = $edgefactor")
    bfs_trial = run(bfs_bench)
    @show minimum(bfs_trial)
    jldopen(filename, "w") do f
        write(f, "bfs_trial", bfs_trial)
    end
end
