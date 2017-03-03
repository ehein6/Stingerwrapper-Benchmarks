using Plots, BenchmarkTools, JLD

function analyzec(nthreads, scaleRange, numtrials, plotname)
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
    p = plot(scaleRange, minruntimes', labels=nthreads', xlabel="Scale", ylabel="log2(Time)",
                markershape=:circle, yscale = :log2, y=10:20, xticks=scaleRange,
                size=(1280, 720), title="C BFS Scaling")
    savefig(plotname)
    minruntimes
end

function analyzejulia(nthreads, scaleRange, plotname)
    results = zeros(length(nthreads), length(scaleRange))
    for (idx, nthread) in enumerate(nthreads)
        bfstimes = load("output/threads_bfs_$nthread.jld")
        for (colidx, scale) in enumerate(scaleRange)
            results[idx, colidx] = minimum(bfstimes["bfs_trial_$(scale)_16"]).time/10^6
        end
    end
    p = plot(scaleRange, results', labels=nthreads', xlabel="Scale", ylabel="log2(Time)",
            markershape=:circle, yscale = :log2, y=10:20, xticks=scaleRange,
            size=(1280, 720), title="Julia BFS Scaling")
    savefig(plotname)
    results
end

function gentable(nthreads, scaleRange, juliaslow)
    print("|Scale/Threads|")
    for i in 1:size(juliaslow', 2)
        print("$(nthreads[i])|")
    end
    print("\n")
    for i in 1:size(juliaslow', 1)
        print("|$(scaleRange[i])|")
        for j in 1:size(juliaslow', 2)
            print("$(round(juliaslow'[i,j], 4))|")
        end
        print("\n")
    end
end

function genthreadplots(nthreads, scaleRange, c, j)
    d = [c;j]
    labels = [["c_$i" for i in nthreads]; ["julia_$i" for i in nthreads]]
    titles = ["$i Threads" for i in nthreads]
    p = plot(scaleRange, d', layout=size(c,1), labels=labels', xlabel="Scale",
    ylabel="Time", markershape=:circle, xticks=scaleRange, title=titles',
    titlefont = font(8), show=true, size=(1280, 720))
    savefig("thread_times.svg")
    p = plot(scaleRange, d', layout=size(c,1), labels=labels', xlabel="Scale",
    ylabel="log(Time)", markershape=:circle, xticks=scaleRange, yscale=:log2, title=titles',
    titlefont = font(12), show=true, size=(1280, 720))
    savefig("thread_times_logscale.svg")
end

function analyze(nthreads, scaleRange, numtrials)
    c = analyzec(nthreads, scaleRange, numtrials, "c_thread_bfs_scaling.svg")
    j = analyzejulia(nthreads, scaleRange, "julia_thread_bfs_scaling.svg")
    juliaslowdownfactors = j./c
    genthreadplots(nthreads, scaleRange, c, j)
    gentable(nthreads, scaleRange, juliaslowdownfactors)
end

pyplot()
analyze([2^i for i in 0:6], 10:20, 3)
