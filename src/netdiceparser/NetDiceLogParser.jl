module NetdiceLogParser

function main()
    tree = Dict{String, Vector{String}}()
    prob = Dict{String, String}()
    active_node = ""

    open("23ecmp.txt") do f 
        while !eof(f)
            line = readline(f)
            # println(line)
            if line[1:9] != "[DEBUG] N"
                continue
            end

            if length(line) >= 20 && line[12:20] == "exploring"
                active_node = line[23:length(line)]
                tree[active_node] = []
            elseif length(line) >= 20 && line[12:20] == "enqueuing"
                push!(tree[active_node], line[23:length(line)])
            else
                prob[active_node] = line[12:length(line)]
                # println(prob[active_node])
            end
        end
    end

    print(print_tree(tree, "[-1, -1, -1, -1, -1, -1, -1, -1]", 1, prob))
    # Do DFS
end

function print_tree(tree, node, depth, prob)
    p = prob[node]
    result = "- $node $p\n"
    for child in tree[node]
        result *= repeat("\t", depth) * print_tree(tree, child, depth + 1, prob)
    end
    return result
end

if !isinteractive()
    main()
end

end # module