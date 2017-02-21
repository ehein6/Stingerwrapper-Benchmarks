const EDGEFACTOR = 16
const scaleRange = 10:20
const nthreads = [2^i for i in 0:6]
const dynographbinarypath = "../stinger-dynograph/build/dynograph"
const qsub_args = ""

using StingerWrapper

function create_directories(directories)
    for dir in directories
        if !isdir(dir)
            mkdir(dir)
        end
    end
end

function generate_kronecker_dump(scale, edgefactor)
   filename = "input/kron_$(scale)_$(edgefactor).graph.el"
   if isfile(filename)
       warn("$filename already exists. Remove the file to be generated again.")
       return
   end
   graph = kronecker(scale, edgefactor)
   open(filename, "w") do f
       for i=1:size(graph,2)
           src = graph[1, i]
           dst = graph[2, i]
           if src == dst
		continue
	   end
           write(f, "$src $dst 1 $i\n")
       end
   end
end

#Generate all the kronecker graphs
function setup()

    create_directories(["input", "output", "scripts"])

    for scale in scaleRange
        srand(0)
        generate_kronecker_dump(scale, EDGEFACTOR)
    end
end

function runbench()
    curdir = dirname(@__FILE__)
    for nthread in nthreads

        script = """#!/bin/bash
        #PBS -N sw_bfs_$(nthread)
        #PBS -l nodes=1:ppn=$(nthread)
        #PBS -l mem=128gb
        #PBS -l walltime=12:00:00
        #PBS -m abe
        #PBS -j oe

        module load gcc/5.3.0

        export OMP_NUM_THREADS=$(nthread)
        export HOOKS_FILENAME=$(joinpath(curdir, "output", "bfs_bench_$(nthread)"))
        $(["$(dynographbinarypath) --alg-names bfs --sort-mode snapshot "*
        "--input-path $(joinpath(curdir, "input", "kron_$(scale)_16.graph.el")) --num-epochs 1 --batch-size 10000 " *
        "--num-trials 3\n" for scale in scaleRange]...)
        """

        open("scripts/stingerwrapperbfsbench_$(nthread).pbs", "w") do f
            write(f, script)
        end

        info("Running dynograph benchmark with $nthread")
        run(`qsub $(qsub_args) scripts/stingerwrapperbfsbench_$(nthread).pbs`)
    end

    dynodir = joinpath(dirname(curdir), "lib", "stinger-dynograph")
    script = """#!/bin/bash
    #PBS -N sw_bfs_$(nthread)
    #PBS -l nodes=1:ppn=$(nthread)
    #PBS -l mem=128gb
    #PBS -l walltime=12:00:00
    #PBS -m abe
    #PBS -j oe

    export STINGER_LIB_PATH=$(joinpath(dynodir, "build", "lib", "stinger", "lib"))
    julia -e "include(\"$(joinpath(curdir, "bfs_bench.jl"))\");benchgroup($scaleRange, $EDGEFACTOR)"
    """

    open("scripts/stingerwrapperbfsbench_julia.pbs", "w") do f
        write(f, script)
    end
    run(`qsub $(qsub_args) scripts/stingerwrapperbfsbench_julia.pbs`)
end

setup()
runbench()
