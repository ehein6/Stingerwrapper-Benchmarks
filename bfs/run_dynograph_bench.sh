#julia generate_kronecker_dump.jl
for i in {10..20}
do
    $1 --alg-names bfs --sort-mode snapshot --input-path kron_${i}_16.graph.el --num-epochs 1 --batch-size 10000 --num-trials 1
done
