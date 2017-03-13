using Base.Threads
using Base.Test
using Base.Threads.Atomic
using LightGraphs
using BenchmarkTools
using UnsafeAtomics

import Base: push!, shift!, isempty, getindex

immutable ThreadQueue{T}
    data::Vector{T}
    head::Atomic{Int}
    tail::Atomic{Int}
end

abstract LGBFSAlgs

immutable NaiveSerialBFS <: LGBFSAlgs end
immutable LevelSynchronous <: LGBFSAlgs end

function ThreadQueue(T::Type, maxlength::Int)
    q = ThreadQueue(Vector{T}(maxlength), Atomic{Int}(1), Atomic{Int}(1))
    return q
end

function push!{T}(q::ThreadQueue{T}, val::T)
    # TODO: check that head > tail
    offset = atomic_add!(q.tail, 1)
    q.data[offset] = val
    return offset
end

function shift!{T}(q::ThreadQueue{T})
    # TODO: check that head < tail
    offset = atomic_add!(q.head, 1)
    return q.data[offset]
end

function isempty(q::ThreadQueue)
    return ( q.head[] == q.tail[] ) && q.head != 1
    # return q.head == length(q.data)
end

function getindex{T}(q::ThreadQueue{T}, iter)
    return q.data[iter]
end

function bfs(alg::NaiveSerialBFS, next::Vector{Int}, g::SimpleGraph, source::Int64)
    parents = fill(-2, nv(g)) #Initialize parents array with -2's.
    parents[source]=-1 #Set source to -1
    while !isempty(next)
        src = shift!(next) #Get first element
        vertexneighbors = neighbors(g, src)
        for vertex in vertexneighbors
            #If not already set, and is not found in the queue.
            if parents[vertex]==-2
                push!(next, vertex) #Push onto queue
                parents[vertex] = src
            end
        end
    end
    return parents
end

function bfskernel(alg::LevelSynchronous, next::ThreadQueue, g::SimpleGraph, parents::Array{Int64}, level::Array{Int64})
    @threads for src in level
        vertexneighbors = neighbors(g, src)
        for vertex in vertexneighbors
            #Set parent value if not set yet.
            parent = UnsafeAtomics.unsafe_atomic_cas!(parents, vertex, -2, src)
            if parent==-2
                push!(next, vertex) #Push onto queue
            end
        end
    end
end

function bfs(
        alg::LevelSynchronous, next::ThreadQueue, g::SimpleGraph, source::Int64,
        parents::Array{Int64}
    )
    parents[source]=-1 #Set source to -1
    push!(next, source)
    while !isempty(next)
        level = next[next.head[]:next.tail[]-1]
        next.head[] = next.tail[] #reset the queue
        bfskernel(alg, next, g, parents, level)
    end
    return parents
end

function bfs(alg::NaiveSerialBFS, g::SimpleGraph, source::Int, nv::Int)
    next = Vector{Int64}([source])
    sizehint!(next, nv)
    return bfs(NaiveSerialBFS(), next, g, source)
end

function bfs(alg::LevelSynchronous, g::SimpleGraph, source::Int64, nv::Int64)
    next = ThreadQueue(Int, nv)
    parents = fill(-2, nv)
    bfs(alg, next, g, source, parents)
end

#Taken from the LightGraphs BFS test
function istree(parents::Vector{Int}, maxdepth)
    flag = true
    for i in 1:maxdepth
        s = i
        depth = 0
        while parents[s] > 0 && parents[s] != s
            s = parents[s]
            depth += 1
            if depth > maxdepth
                return false
            end
        end
    end
    return flag
end

function testbfsalgs(g::SimpleGraph)
    n = nv(g)
    visitor = LightGraphs.TreeBFSVisitorVector(zeros(Int,n))
    LightGraphs.bfs_tree!(visitor, g, 1)
    @test istree(visitor.tree, n)
    @test istree(bfs(NaiveSerialBFS(), g, 1, n), n)
    @test istree(bfs(LevelSynchronous(), g, 1, n), n)
    @test istree(bfs(ParallBFS(), g, 1, n), n)
end
