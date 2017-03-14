using Plots, BenchmarkTools, JLD

function analyzec(nthreads, scaleRange, edgefactor, numtrials, plotname)
    results = zeros(length(nthreads), length(scaleRange), numtrials)
    for (idx, nthread) in enumerate(nthreads)
        for (scaleIdx, scale) in enumerate(scaleRange)
                bfstimes = split(readstring(`grep "bfs" output/dynograph/dynograph_$(nthread)_$(scale)_$(edgefactor)`))
            for trial in 1:numtrials
                results[idx, scaleIdx, trial] = float(split(split(bfstimes[trial], ",")[end-1], ":")[2])
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

function analyzestingerwrapper(nthreads, scaleRange, edgefactor, plotname)
    results = zeros(length(nthreads), length(scaleRange))
    for (idx, nthread) in enumerate(nthreads)
        for (colidx, scale) in enumerate(scaleRange)
            bfstimes = load("output/stingerwrapper/stingerwrapper_$(nthread)_$(scale)_$(edgefactor).jld")
            results[idx, colidx] = minimum(bfstimes["bfs_trial"]).time/10^6
        end
    end
    p = plot(scaleRange, results', labels=nthreads', xlabel="Scale", ylabel="log2(Time)",
            markershape=:circle, yscale = :log2, y=10:20, xticks=scaleRange,
            size=(1280, 720), title="StingerWrapper BFS Scaling")
    savefig(plotname)
    results
end

function analyzelg(nthreads, scaleRange, edgefactor, plotname)
    results = zeros(length(nthreads), length(scaleRange))
    visitorlg = zeros(1, length(scaleRange))
    for (idx, nthread) in enumerate(nthreads)
        for (colidx, scale) in enumerate(scaleRange)
            bfstimes = load("output/lg/lg_$(nthread)_$(scale)_$(edgefactor).jld")
            results[idx, colidx] = minimum(bfstimes["bfs_trial"]).time/10^6
        end
    end
    for (idx, scale) in enumerate(scaleRange)
        try
            bfstimes = load("output/lg/lg_visitor_$(scale)_$(edgefactor).jld")
            visitorlg[1, idx] = minimum(bfstimes["bfs_trial"]).time/10^6
        catch
            visitorlg[1, idx] = NaN
        end
    end
    p = plot(scaleRange, results', labels=nthreads', xlabel="Scale", ylabel="log2(Time)",
            markershape=:circle, yscale = :log2, y=10:20, xticks=scaleRange,
            size=(1280, 720), title="LG BFS Scaling")
    savefig(plotname)
    results, visitorlg
end

function parefficiency(times, scaleRange, nthreads, plotname, title)
    serial = copy(times[1, :])
    parefficiency = zeros(size(times))
    for i=1:size(times, 1)
        p = nthreads[i]
        parefficiency[i, :] = serial ./ (times[i,:] * p)
    end
    p = plot(nthreads, parefficiency, labels=collect(scaleRange)', xlabel="Scale", ylabel="Parallel Efficiency",
                markershape=:circle, xticks=nthreads,
                size=(1280, 720), title="Parallel Efficiency: $title")
    savefig(plotname)
    parefficiency
end

function speedup(times, scaleRange, nthreads, plotname, title)
    serial = copy(times[1, :])
    speedups = zeros(size(times))
    for i=1:size(times, 1)
        speedups[i, :] = serial ./ (times[i,:])
    end
    p = plot(nthreads, speedups, labels=collect(scaleRange)', xlabel="Scale", ylabel="Speedup",
                markershape=:circle, xticks=nthreads,
                size=(1280, 720), title="Speedup: $title")
    savefig(plotname)
    speedups
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

function genthreadplots(nthreads, scaleRange, c, sw, l, visitorlg)
    d = [c;sw;l;visitorlg]
    labels = [["stinger_c_$i" for i in nthreads]; ["stinger_jl_$i" for i in nthreads]; ["lg_$i" for i in nthreads]; "lgvisitorbfs"]
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
    c = analyzec(nthreads, scaleRange, 16, numtrials, "stinger_bfs_scaling.svg")
    j = analyzestingerwrapper(nthreads, scaleRange, 16, "stingerwrapper_bfs_scaling.svg")
    lg, visitorlg = analyzelg(nthreads, scaleRange, 16, "lg_bfs_scaling.svg")
    #juliaslowdownfactors = j./c
    genthreadplots(nthreads, scaleRange, c, j, lg, visitorlg)
    parefficiency(c, scaleRange, nthreads, "parefficiency_c.svg", "STINGER C - Efficiency")
    parefficiency(lg, scaleRange, nthreads, "parefficiency_lg.svg", "LG - Efficiency")
    parefficiency(j, scaleRange, nthreads, "parefficiency_stingerwrapper.svg", "StingerWrapper.jl - Efficiency")
    speedup(c, scaleRange, nthreads, "speedup_c.svg", "STINGER C - Speedup")
    speedup(lg, scaleRange, nthreads, "speedup_lg.svg", "LG - Speedup")
    speedup(j, scaleRange, nthreads, "speedup_stingerwrapper.svg", "StingerWrapper.jl - Speedup")
    #gentable(nthreads, scaleRange, juliaslowdownfactors)
    c, j, lg, visitorlg
end

pyplot()
analyze([2^i for i in 0:6], 10:22, 3)
