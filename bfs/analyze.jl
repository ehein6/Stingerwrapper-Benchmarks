using Plots

pyplot()
function analyze(nthreads, scaleRange, numtrials, plotname)
    results = zeros(length(nthreads), length(scaleRange), numtrials)
    for (idx, nthread) in enumerate(nthreads)
        bfstimes = split(readstring(`grep "bfs" output/bfs_bench_$nthread`))
        for scale in 1:length(scaleRange)
            for trial in 1:numtrials
                results[idx, scale, trial] = float(split(split(bfstimes[(scale-1)*numtrials + trial], ",")[end-1], ":")[2])
            end
        end
    end
    minruntimes = min([results[:, :, i] for i in 1:numtrials]...)
    p = plot(minruntimes', labels=nthreads', xlabel="Scale", ylabel="log2(Time)",
                markershape=:circle, yscale = :log2, y=10:20)
    savefig(plotname)
    results
end

analyze([2^i for i in 0:6], 10:20, 3, "bfs_times_threads.svg")
