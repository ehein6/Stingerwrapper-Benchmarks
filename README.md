# Stingerwrapper-Benchmarks

[![Build Status](https://travis-ci.org/rohitvarkey/Stingerwrapper-Benchmarks.svg?branch=master)](https://travis-ci.org/rohitvarkey/Stingerwrapper-Benchmarks)

This repository defines benchmarks of running BFS for RMAT graphs for [STINGER](https://github.com/stingergraph/stinger) (using [Dynograph](https://github.com/DynoGraph/stinger-dynograph)), [StingerWrapper.jl](https://github.com/rohitvarkey/StingerWrapper.jl),
and [LightGraphs.jl](https://github.com/JuliaGraphs/LightGraphs.jl).

### Building the benchmark suite

#### Set up
`git clone --recursive https://github.com/rohitvarkey/Stingerwrapper-Benchmarks`
or
```bash
git clone https://github.com/rohitvarkey/Stingerwrapper-Benchmarks
cd Stingerwrapper-Benchmarks
git submodule update --init
```

#### Building dynograph and stinger

```bash
cd lib/stinger-dynograph
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release .. && make -j$(nproc) dynograph
```

### Running the Benchmarks

The `generate_scripts.jl` Julia script generates the RMAT graphs, the scripts to
run the benchmarks and starts the benchmarks. By default, it assumes you are running
this is a HPC cluster with `qsub`. To run on such a cluster

```julia
include("generate_scripts.jl")
runbench([2^i for i=0:6], 10:28, 16, useremail="you@email.com", queue="your-queue")
```

You can also use `bash` to run these scripts by calling

```julia
include("generate_scripts.jl")
runbench([2^i for i=0:6], 10:28, 16, qsub=false)
```