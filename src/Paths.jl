module Paths

using Graphs
using MetaGraphsNext
using DataStructures

function get_reducible_paths_yen(g::AbstractGraph, src::Symbol, dst::Symbol, K::Int)::Vector{Vector{Symbol}}
     yen = yen_k_shortest_paths(g.graph, code_for(g, src), code_for(g, dst), weights(g), K)
     reduciblepaths::Vector{Vector{Symbol}} = map(x -> map(x_i -> label_for(g, x_i), x), yen.paths)
     return reduciblepaths
end

function modified_yen(g::AbstractGraph,
     source::U,
     target::U,
     distmx::AbstractMatrix{T}=weights(g);
     # K::Int=1;
     maxdist=Inf) where T <: Real where U <: Integer

     # source == target && return YenState{T,U}([U(0)], [[source]])
     source == target && return [[source]]
     
     p_explored = 0.0
     p_property = 0.0

     # GET SHORTEST PATH GIVEN PERFECT NETWORK
     dj = dijkstra_shortest_paths(g, source, distmx)
     path = enumerate_paths(dj)[target] # only outputs a single path even though allpath is true
     
     # isempty(path) && return YenState{T,U}(Vector{T}(), Vector{Vector{U}}())
     if isempty(path)
          p_explored = 1.0
          return []
     end

     ################
     p_state = 0.9 ^ (size(path)[1] - 1) # 0.9^links
     p_explored += p_state
     p_property += p_state
     println(p_explored)
     ################

     # dists = Array{T,1}()
     # push!(dists, dj.dists[target])
     A = [path]
     B = PriorityQueue()
     gcopy = deepcopy(g)

     ################
     causality = Dict()
     causality_prob = Dict()
     ################

     # for k = 1:(K - 1)
     k = 1
     while true
          println(k)
          for j = 1:length(A[k])
               #################
               # TODO: update j to not contain intersection
               p_state = 0.9^(j-1) * 0.1
               # TODO: causality
               #################

               # STEP 1: DETERMINE ROOT PATH AND FAIL SPECIFIC LINKS
               # Spur node is retrieved from the previous k-shortest path, k − 1
               spurnode = A[k][j]
               #  The sequence of nodes from the source to the spur node of the previous k-shortest path
               rootpath = A[k][1:j]

               # Remove the links of the previous shortest paths which share the same root path
               # Store the removed edges
               edgesremoved = Array{Tuple{Int,Int},1}()
               for ppath in A
                    if length(ppath) > j && rootpath == ppath[1:j]
                         u = ppath[j]
                         v = ppath[j + 1]
                         if has_edge(gcopy, u, v)
                              rem_edge!(gcopy, u, v)
                              push!(edgesremoved, (u, v))
                         end
                    end
               end

               # STEP 2: DETERMINE SPUR PATH (shortest path between spur node and dst)
               # Remove node of root path and calculate dist of it
               distrootpath = 0.
               for n = 1:(length(rootpath) - 1)
                    u = rootpath[n]
                    nei = copy(neighbors(gcopy, u))
                    for v in nei
                         rem_edge!(gcopy, u, v)
                         push!(edgesremoved, (u, v))
                    end

                    # Evaluate distance of root path
                    v = rootpath[n + 1]
                    distrootpath += distmx[u, v]
               end

               # Calculate the spur path from the spur node to the sink
               djspur = dijkstra_shortest_paths(gcopy, spurnode, distmx)
               spurpath = enumerate_paths(djspur)[target]

               # STEP 3: COLLECT TOTAL PATH
               # REACHABILITY HERE -> no spur path == not reachable
               if !isempty(spurpath)
                    # Entire path is made up of the root path and spur path
                    pathtotal = [rootpath[1:(end - 1)]; spurpath]
                    distpath  = distrootpath + djspur.dists[target]
                    # Add the potential k-shortest path to the heap, if it's new
                    if !haskey(B, pathtotal)
                         enqueue!(B, pathtotal, distpath)
                    end
               end

               for (u, v) in edgesremoved
                    add_edge!(gcopy, u, v)
               end
          end

          # No more paths in B
          isempty(B) && break
          # mindistB = peek(B)[2]
          # The path with minimum distance in B is higher than maxdist
          # mindistB > maxdist && break
          # push!(dists, peek(B)[2])
          push!(A, dequeue!(B))
          k += 1
     end

     # return YenState{T,U}(dists, A)
     return A
end

end # module