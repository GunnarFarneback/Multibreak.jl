"""
The Multibreak package provides the `@multibreak` macro for breaking
out of, and optionally continuing, several nested loops at once.

The simplest use is of the form
```
using Multibreak

@multibreak for i = 1:5
    for j = 1:5
        break; break
    end
end
```
Read the tutorial at $(abspath(dirname(@__DIR__), "test",
"tutorial.jl")) or
https://github.com/GunnarFarneback/Multibreak.jl/blob/master/test/tutorial.jl
for the full documentation.
"""
module Multibreak
export @multibreak

function multibreak_transform_break_and_continue(args, active_loops)
    out = Any[]
    nbreak = 0
    ncontinue = 0
    for arg in args
        if Meta.isexpr(arg, :break)
            if ncontinue > 0
                push!(out, :(error("multibreak: continue cannot precede a break")))
            end
            nbreak += 1
        elseif Meta.isexpr(arg, :continue)
            if ncontinue > 0
                push!(out, :(error("multibreak: multiple continue not allowed")))
            end
            ncontinue += 1
        elseif typeof(arg) == LineNumberNode
            push!(out, arg)
        else
            push!(out, arg)
        end
    end
    n = nbreak + ncontinue
    if  n > length(active_loops)
        push!(out, :(error("multibreak: not enough nested loops for requested multiple break/continue")))
    elseif n > 0
        push!(out, Expr(:symbolicgoto,
                        Symbol("loop",
                               active_loops[end - n + 1],
                               ncontinue == 0 ? "break" : "continue")))
    end
    return out
end

function multibreak_transform_ast(ast, loop_counter = [1], active_loops = Int[])
    if typeof(ast) != Expr
        return ast
    end

    if ast.head == :for
        n = loop_counter[1]
        active_loops = vcat(active_loops, n)
        loop_counter[1] += 1
    end

    args = [multibreak_transform_ast(arg, loop_counter, active_loops) for arg in ast.args]

    if ast.head == :for
        arg2 = Expr(:block,
                    args[2],
                    Expr(:symboliclabel, Symbol("loop", n, "continue")))
        return Expr(:block,
                    Expr(:for, args[1], arg2),
                    Expr(:symboliclabel, Symbol("loop", n, "break")))
    elseif ast.head == :block
        return Expr(:block,
                    multibreak_transform_break_and_continue(args, active_loops)...)
    end

    return Expr(ast.head, args...)
end

# TODO: This string repeats parts of the module documentation
# string. The common parts should be reused but first find out how to
# do that without running into scoping issues.
"""
`@multibreak` allows breaking out of, and optionally continuing,
several nested loops at once.

The simplest use is of the form
```
using Multibreak

@multibreak for i = 1:5
    for j = 1:5
        break; break
    end
end
```
Read the tutorial at $(abspath(dirname(@__DIR__), "test",
"tutorial.jl")) or
https://github.com/GunnarFarneback/Multibreak.jl/blob/master/test/tutorial.jl
for the full documentation.
"""
macro multibreak(blk)
    esc(multibreak_transform_ast(blk))
end

end
