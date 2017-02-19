using StingerWrapper

function generate_kronecker_dump(scale, edgefactor)
   filename = "kron_$(scale)_$(edgefactor).graph.el"
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

for i=10:20
    srand(0)
    generate_kronecker_dump(i, 16)
end
