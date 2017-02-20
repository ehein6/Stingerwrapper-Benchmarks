using Plots

function analyze(nthreads, scaleRange, plotname)
    results = zeros(length(nthreads), length(scaleRange))
    for (idx, nthread) in enumerate(nthreads)
        @show bfstimes = readstring(`grep "bfs" output/bfs_bench_$nthread`)
        for (lineidx, line) in enumerate(split(bfstimes))
            results[idx, lineidx] = float(split(split(line, ",")[end-1], ":")[2])
        end
    end
    p = plot(results)
    savefig(plotname)
    results
end

analyze([2^i for i in 0:6], 10:20, "bfs_times_threads.svg")
