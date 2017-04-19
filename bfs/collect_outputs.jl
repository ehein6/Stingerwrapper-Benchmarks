using JLD, JSON, DataFrames, BenchmarkTools

function collect_lg_outputs(lgoutputdirectory)
    lg_regex =  r"lg_(?P<threads>\d+)_(?P<scale>\d+)_(?P<edgefactor>\d+).jld"
    allfiles = readdir(lgoutputdirectory)
    lgfiles = filter(x->ismatch(lg_regex, x), allfiles)
    lg_df = DataFrame([Symbol, Int64, Int64, Int64, Float64], [:Type, :Threads, :Scale, :Edgefactor, :MinimumTime], 0)
    for lgmatch in [match(lg_regex, x) for x in lgfiles]
        lgfile = lgmatch.match
        bfstimes = load(joinpath(lgoutputdirectory, lgfile))
        result = minimum(bfstimes["bfs_trial"]).time/10^6
        push!(lg_df, @data [:LG, parse(Int, lgmatch[:threads]), parse(Int, lgmatch[:scale]), parse(Int, lgmatch[:edgefactor]), result])
    end
    lg_visitor_regex =  r"lg_visitor_(?P<scale>\d+)_(?P<edgefactor>\d+).jld"
    lgvisitorfiles = filter(x->ismatch(lg_visitor_regex, x), allfiles)
    for lgmatch in [match(lg_visitor_regex, x) for x in lgvisitorfiles]
        lgfile = lgmatch.match
        bfstimes = load(joinpath(lgoutputdirectory, lgfile))
        result = minimum(bfstimes["bfs_trial"]).time/10^6
        push!(lg_df, @data [:LGVisitor, 1, parse(Int, lgmatch[:scale]), parse(Int, lgmatch[:edgefactor]), result])
    end
    lg_df
end

function collect_stingerwrapper_outputs(stingeroutputdirectory)
    stingerwrapper_regex =  r"stingerwrapper_(?P<threads>\d+)_(?P<scale>\d+)_(?P<edgefactor>\d+).jld"
    allfiles = readdir(stingeroutputdirectory)
    stingerwrapperfiles = filter(x->ismatch(stingerwrapper_regex, x), allfiles)
    stingerwrapper_df = DataFrame([Symbol, Int64, Int64, Int64, Float64], [:Type, :Threads, :Scale, :Edgefactor, :MinimumTime], 0)
    for stingerwrappermatch in [match(stingerwrapper_regex, x) for x in stingerwrapperfiles]
        stingerwrapperfile = stingerwrappermatch.match
        bfstimes = load(joinpath(stingeroutputdirectory, stingerwrapperfile))
        result = minimum(bfstimes["bfs_trial"]).time/10^6
        push!(
            stingerwrapper_df,
            @data [:StingerWrapper, parse(Int, stingerwrappermatch[:threads]), parse(Int, stingerwrappermatch[:scale]), parse(Int, stingerwrappermatch[:edgefactor]), result]
        )
    end
    stingerwrapper_df
end

function parsedyno(dynofile, numtrials=3)
    bfstimes = zeros(0)
    for line in eachline(dynofile)
        try
            dynojson = JSON.parse(line)
            if (dynojson["region_name"] == "bfs")
                push!(bfstimes, dynojson["time_ms"])
            end
        catch
            continue
        end
    end
    minimum(bfstimes[end-numtrials+1:end])
end

function collect_dynograph_outputs(dynographoutputdirectory, numtrials=3)
    dyno_regex =  r"dynograph_(?P<threads>\d+)_(?P<scale>\d+)_(?P<edgefactor>\d+)"
    allfiles = readdir(dynographoutputdirectory)
    dynofiles = filter(x->ismatch(dyno_regex, x), allfiles)
    dyno_df = DataFrame([Symbol, Int64, Int64, Int64, Float64], [:Type, :Threads, :Scale, :Edgefactor, :MinimumTime], 0)
    for dynomatch in [match(dyno_regex, x) for x in dynofiles]
        dynofile = dynomatch.match
        result = parsedyno(joinpath(dynographoutputdirectory, dynofile))
        push!(
            dyno_df,
            @data [:Stinger, parse(Int, dynomatch[:threads]), parse(Int, dynomatch[:scale]), parse(Int, dynomatch[:edgefactor]), result]
        )
    end
    dyno_df
end

function collect_all_data(outputdir="output/";dyno_trials=3)
    lg_df = collect_lg_outputs(joinpath(outputdir, "lg"))
    stingerwrapper_df = collect_stingerwrapper_outputs(joinpath(outputdir, "stingerwrapper"))
    dyno_df = collect_dynograph_outputs(joinpath(outputdir, "dynograph"), dyno_trials)
    writetable(joinpath(outputdir, "lg.csv"), lg_df)
    writetable(joinpath(outputdir, "stingerwrapper.csv"), stingerwrapper_df)
    writetable(joinpath(outputdir, "dynograph.csv"), dyno_df)
end

collect_all_data()
