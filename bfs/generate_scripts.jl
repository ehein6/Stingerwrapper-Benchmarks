using StingerWrapper

function create_directories(directories)
    curdir = dirname(@__FILE__)
    for dirname in directories
        dir = joinpath(curdir, dirname)
        if !isdir(dir)
            mkdir(dir)
        end
    end
end

function generate_kronecker_dump(scale, edgefactor)
   curdir = dirname(@__FILE__)
   filename = joinpath(curdir, "input", "kron_$(scale)_$(edgefactor).graph.el")
   if isfile(filename)
       warn("$filename already exists. Remove the file to be generated again.")
       return
   end
   srand(0)
   graph = kronecker(scale, edgefactor)
   open(filename, "w") do f
       for i=1:size(graph,2)
           src = graph[1, i]
           dst = graph[2, i]
           if src != dst
               write(f, "$src $dst 1 1\n")
	       end
       end
   end
end

function lg_bench_script(scale, edgefactor, filename, nthreads)
    curdir = dirname(@__FILE__)
    lgbenchfile = joinpath(curdir, "lg_bfs_bench.jl")
    lgscript = """
    export JULIA_NUM_THREADS=$(nthreads)
    julia -e 'include("$lgbenchfile"); lg_bench($scale, $edgefactor, "$filename")'
    """
    lgscript
end

function lg_visitor_bench_script(scale, edgefactor, filename, nthreads)
    curdir = dirname(@__FILE__)
    lgbenchfile = joinpath(curdir, "lg_bfs_bench.jl")
    lgscript = """
    export JULIA_NUM_THREADS=$(nthreads)
    julia -e 'include("$lgbenchfile"); lg_visitor_bench($scale, $edgefactor, "$filename")'
    """
    lgscript
end

function stingerwrapper_bench_script(scale, edgefactor, filename, nthreads)
    curdir = dirname(@__FILE__)
    stingerwrapperbenchfile = joinpath(curdir, "stingerwrapper_bfs_bench.jl")
    stingerwrapperscript = """
    export JULIA_NUM_THREADS=$(nthreads)
    julia -e 'include("$stingerwrapperbenchfile"); stingerwrapper_bench($scale, $edgefactor, "$filename")'
    """
    stingerwrapperscript
end

function dynograph_bench_script(scale, edgefactor, filename, nthreads)
    curdir = dirname(@__FILE__)
    dynodir = joinpath(dirname(curdir), "lib", "stinger-dynograph")
    dynographbinarypath = joinpath(dynodir, "build", "dynograph")
    dynoscript = """
    export OMP_NUM_THREADS=$(nthreads)
    export HOOKS_FILENAME=$(filename)
    $(dynographbinarypath) --alg-names bfs --sort-mode snapshot --input-path $(joinpath(curdir, "input", "kron_$(scale)_$(edgefactor).graph.el")) --num-epochs 1 --batch-size 10000 --num-trials 3
    """
    dynoscript
end

function qsub_header(nthread, job, scale, edgefactor, useremail="", queue="")
    header = """#PBS -N $(job)_$(nthread)_$(scale)
    #PBS -l nodes=1:ppn=$(nthread)
    #PBS -l walltime=12:00:00
    #PBS -l mem=160gb
    #PBS -m abe
    #PBS -M $useremail
    #PBS -q $queue
    #PBS -j oe
    module load gcc/5.3.0
    """
    header
end

#Generate all the kronecker graphs
function runbench(nthreads, scaleRange, edgefactor; qsub=true, useremail="", queue="")

    #Create the directories
    create_directories(["input", "output", "scripts"])
    for dir in ("output", "scripts")
        create_directories(["$dir/stingerwrapper", "$dir/dynograph", "$dir/lg"])
    end

    #Generate the inputs
    for scale in scaleRange
        generate_kronecker_dump(scale, edgefactor)
    end

    #Generate the scripts
    curdir = dirname(@__FILE__)
    outputdir = joinpath(curdir, "output")
    scriptdir = joinpath(curdir, "scripts")
    for scale in scaleRange
        for nthread in nthreads
            lgscript = lg_bench_script(scale, edgefactor, joinpath(outputdir, "lg", "lg_$(nthread)_$(scale)_$(edgefactor).jld"), nthread)
            stingerwrapperscript = stingerwrapper_bench_script(scale, edgefactor, joinpath(outputdir, "stingerwrapper", "stingerwrapper_$(nthread)_$(scale)_$(edgefactor).jld"), nthread)
            dynographscript = dynograph_bench_script(scale, edgefactor, joinpath(outputdir, "dynograph", "dynograph_$(nthread)_$(scale)_$(edgefactor)"), nthread)
            lgscript = """#!/bin/bash
            $(if qsub qsub_header(nthread, "lg", scale, edgefactor, useremail, queue) else "" end)
            $(lgscript)
            """
            stingerwrapperscript = """#!/bin/bash
            $(if qsub qsub_header(nthread, "sw", scale, edgefactor, useremail, queue) else "" end)
            $(stingerwrapperscript)
            """
            dynographscript = """#!/bin/bash
            $(if qsub qsub_header(nthread, "dynograph", scale, edgefactor, useremail, queue) else "" end)
            $(dynographscript)
            """
            open(joinpath(scriptdir, "lg", "lg_$(nthread)_$(scale)_$(edgefactor)"), "w") do f
                write(f, lgscript)
            end
            open(joinpath(scriptdir, "stingerwrapper", "stingerwrapper_$(nthread)_$(scale)_$(edgefactor)"), "w") do f
                write(f, stingerwrapperscript)
            end
            open(joinpath(scriptdir, "dynograph", "dynograph_$(nthread)_$(scale)_$(edgefactor)"), "w") do f
                write(f, dynographscript)
            end
            if qsub
                run(`qsub $(joinpath(scriptdir, "lg", "lg_$(nthread)_$(scale)_$(edgefactor)"))`)
                run(`qsub $(joinpath(scriptdir, "stingerwrapper", "stingerwrapper_$(nthread)_$(scale)_$(edgefactor)"))`)
                run(`qsub $(joinpath(scriptdir, "dynograph", "dynograph_$(nthread)_$(scale)_$(edgefactor)"))`)
            else
                run(`bash $(joinpath(scriptdir, "lg", "lg_$(nthread)_$(scale)_$(edgefactor)"))`)
                run(`bash $(joinpath(scriptdir, "stingerwrapper", "stingerwrapper_$(nthread)_$(scale)_$(edgefactor)"))`)
                run(`bash $(joinpath(scriptdir, "dynograph", "dynograph_$(nthread)_$(scale)_$(edgefactor)"))`)
            end
            if nthread == 1
                lgvisitorscript = lg_visitor_bench_script(scale, edgefactor, joinpath(outputdir, "lg", "lg_visitor_$(scale)_$(edgefactor).jld"), nthread)
                lgvisitorscript = """#!/bin/bash
                $(if qsub qsub_header(nthread, "lgvisitor", scale, edgefactor, useremail, queue) else "" end)
                $(lgvisitorscript)
                """
                open(joinpath(scriptdir, "lg", "lg_visitor_$(scale)_$(edgefactor)"), "w") do f
                    write(f, lgvisitorscript)
                end
                if qsub
                    run(`qsub $(joinpath(scriptdir, "lg", "lg_visitor_$(scale)_$(edgefactor)"))`)
                else
                    run(`bash $(joinpath(scriptdir, "lg", "lg_visitor_$(scale)_$(edgefactor)"))`)
                end
            end
        end
    end
end

#runbench()
