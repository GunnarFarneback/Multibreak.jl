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

# This may be changed to just v"1.14" after it has been released.
const use_labeled_break = VERSION >= v"1.14.0-DEV.1613"

function multibreak_transform_break_and_continue(args, break_labels)
    out = Any[]
    nbreak = 0
    ncontinue = 0
    for arg in args
        if Meta.isexpr(arg, :break)
            if ncontinue > 0
                push!(out, :(error("multibreak: continue cannot precede a break")))
            end
            if isempty(arg.args)
                nbreak += 1
            elseif nbreak > 0
                push!(out, :(error("multibreak: labeled break cannot be used in a multibreak combination")))
            else
                push!(out, arg)
            end
        elseif Meta.isexpr(arg, :continue)
            if ncontinue > 0
                push!(out, :(error("multibreak: multiple continue not allowed")))
            end
            if isempty(arg.args)
                ncontinue += 1
            elseif nbreak > 0
                push!(out, :(error("multibreak: labeled continue cannot be used in a multibreak combination")))
            else
                push!(out, arg)
            end
        elseif typeof(arg) == LineNumberNode
            push!(out, arg)
        else
            if nbreak + ncontinue > 0
                emit_labeled_break!(out, break_labels, nbreak, ncontinue)
                nbreak = 0
                ncontinue = 0
            end
            push!(out, arg)
        end
    end
    if nbreak + ncontinue > 0
        emit_labeled_break!(out, break_labels, nbreak, ncontinue)
    end
    return out
end

function emit_labeled_break!(out, break_labels, nbreak, ncontinue)
    n = nbreak + ncontinue
    break_or_continue = (ncontinue == 0) ? (:break) : (:continue)
    if n > length(break_labels)
        push!(out, :(error("multibreak: not enough nested loops for requested multiple break/continue")))
        return
    elseif n == 1
        push!(out, Expr(break_or_continue))
        return
    elseif n == 0
        return
    end

    if use_labeled_break
        push!(out, Expr(break_or_continue, break_labels[end - n + 1]))
    else
        label = break_labels[end - n + 1]
        if ncontinue > 0
            label = Symbol(label, "#cont")
        end
        push!(out, Expr(:symbolicgoto, label))
    end
    return
end

function multibreak_transform_ast(ast, break_labels = Symbol[],
                                  label = nothing)
    if typeof(ast) != Expr
        return ast
    end

    if ast.head == :for || ast.head == :while
        if label === nothing
            break_label = gensym(Symbol("break"))
        else
            break_label = label
        end
        break_labels = vcat(break_labels, break_label)
    end

    # If we find a labeled loop, reuse that label instead of adding
    # our own label.
    recursed_label = nothing
    if (ast.head == :macrocall
        && length(ast.args) >= 3
        && ast.args[1] == Symbol("@label")
        && any(Meta.isexpr(arg, (:for, :while)) for arg in ast.args[2:end]))

        symbols = filter(x -> x isa Symbol, ast.args[2:end])
        if !isempty(symbols)
            recursed_label = first(symbols)
        end
    end

    args = [multibreak_transform_ast(arg, break_labels, recursed_label)
            for arg in ast.args]

    if (ast.head == :for || ast.head == :while) && label === nothing
        if use_labeled_break
            return Expr(:symbolicblock,
                        last(break_labels),
                        Expr(ast.head, args[1],
                             Expr(:symbolicblock,
                                  Symbol(last(break_labels), "#cont"),
                                  args[2])))
        else
            arg2 = Expr(:block,
                        args[2],
                        Expr(:symboliclabel, Symbol(last(break_labels), "#cont")))
            return Expr(:block,
                        Expr(ast.head, args[1], arg2),
                        Expr(:symboliclabel, last(break_labels)))
        end
    elseif ast.head == :block
        return Expr(:block,
                    multibreak_transform_break_and_continue(args, break_labels)...)
    end

    return Expr(ast.head, args...)
end

# TODO: This string repeats parts of the module documentation
# string. The common parts should be reused but first find out how to
# do that without running into scoping issues.
#
# The scoping issue is that the module docstring needs to be defined
# outside of the module, which is not allowed. It cannot be defined
# inside the module, since the module has not been evaluated at the
# time the docstring is attached. It's also not possible to use `@doc`
# to attach the module docstring afterwards.
const macro_docstring =
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
