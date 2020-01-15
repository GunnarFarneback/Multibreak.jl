using Multibreak

# This file serves the dual purpose of both testing the package and
# being a tutorial to the functionality.

# The first example showcases the semantics of multiple
# `break`/`continue` in ordinary Julia code. Effectively only the
# first `break`/`continue` is executed and additional ones are simply
# unreachable code.
@testset MBTestSet "standard Julia" begin
    out = []
    for i = 1:5
        for j = 1:3
            if i == 1 && j == 1
                continue
            elseif i == 2 && j == 2
                break
            elseif i == 3 && j == 2
                break; continue
            elseif i == 4 && j == 2
                break; break
            end
            push!(out, (i, j))
        end
        push!(out, i)
    end

    @test out == [(1, 2), (1, 3), 1,
                  (2, 1), 2,
                  (3, 1), 3,
                  (4, 1), 4,
                  (5, 1), (5, 2), (5, 3), 5]
end

# With the `@multibreak` macro, the semantics of multiple
# `break`/`continue` is changed to a sequence of `break`/`continue`
# statements outwards through the enclosing loops. Once a `continue`
# is reached, the process ends. Thus there can be any number of
# `break`, optionally followed by a `continue`. Obviously there cannot
# be more `break`/`continue` than nested loop levels, however.
@testset MBTestSet "multibreak macro" begin
    out = []
    @multibreak begin
        for i = 1:5
            for j = 1:3
                if i == 1 && j == 1
                    continue
                elseif i == 2 && j == 2
                    break
                elseif i == 3 && j == 2
                    break; continue
                elseif i == 4 && j == 2
                    break; break
                end
                push!(out, (i, j))
            end
            push!(out, i)
        end
    end

    @test out == [(1, 2), (1, 3), 1,
                  (2, 1), 2,
                  (3, 1),
                  (4, 1)]
end

# This shows how the previous example can be coded with the `goto` and
# `label` macros instead of the `@multibreak` macro. This is in fact
# how the `@multibreak` macro works internally and should make the
# semantics clear.
@testset MBTestSet "goto and label" begin
    out = []
    for i = 1:5
        for j = 1:3
            if i == 1 && j == 1
                @goto loop2continue
            elseif i == 2 && j == 2
                @goto loop2break
            elseif i == 3 && j == 2
                @goto loop1continue
            elseif i == 4 && j == 2
                @goto loop1break
            end
            push!(out, (i, j))
            @label loop2continue
        end
        @label loop2break
        push!(out, i)
        @label loop1continue
    end
    @label loop1break

    @test out == [(1, 2), (1, 3), 1,
                  (2, 1), 2,
                  (3, 1),
                  (4, 1)]
end

# `@multibreak` can be applied directly to the outer loop statement
# instead of to an enclosing block as was done earlier. If the nested
# loop is the only thing in the block, this is only a stylistic
# difference.
@testset MBTestSet "multibreak applied to outer for" begin
    out = []
    @multibreak for i = 1:5
        for j = 1:3
            if i == 1 && j == 1
                continue
            elseif i == 2 && j == 2
                break
            elseif i == 3 && j == 2
                break; continue
            elseif i == 4 && j == 2
                break; break
            end
            push!(out, (i, j))
        end
        push!(out, i)
    end

    @test out == [(1, 2), (1, 3), 1,
                  (2, 1), 2,
                  (3, 1),
                  (4, 1)]
end

# If preferred, `@multibreak` can be applied to an entire function.
@testset MBTestSet "multibreak applied to function" begin
    @multibreak function f()
        out = []
        for i = 1:5
            for j = 1:3
                if i == 1 && j == 1
                    continue
                elseif i == 2 && j == 2
                    break
                elseif i == 3 && j == 2
                    break; continue
                elseif i == 4 && j == 2
                    break; break
                end
                push!(out, (i, j))
            end
            push!(out, i)
        end
        return out
    end

    @test f() == [(1, 2), (1, 3), 1,
                  (2, 1), 2,
                  (3, 1),
                  (4, 1)]
end

# When `@multibreak` is applied to an entire function, multiple
# `break`/`continue` is available in all loops in the function.
@testset MBTestSet "multibreak applied to function with two loops" begin
    @multibreak function f()
        m = 0
        for i = 1:5
            for j = 1:3
                m += 1
                if i + j > 5
                    break; continue
                end
            end
        end

        n = 0
        for i = 1:5
            for j = 1:3
                n += 1
                if i + j > 5
                    break; break
                end
            end
        end

        return m, n
    end

    @test f() == (12, 9)
end

# You are not allowed to break out of more loops than there are.
@testset MBTestSet "too many break" begin
    @multibreak function f()
        for i = 1:5
            break; break
        end
    end

    @test_throws ErrorException f()
end

# Neither continue after breaking out of all the loops.
@testset MBTestSet "too many break and continue" begin
    @multibreak function f()
        for i = 1:5
            for j = 1:3
                if i + j > 5
                    break; break; continue
                end
            end
        end
    end

    @test_throws ErrorException f()
end

# It doesn't make sense to break out of a loop after having continued it.
@testset MBTestSet "continue before break" begin
    @multibreak function f()
        for i = 1:5
            for j = 1:3
                if i + j > 5
                    continue; break
                end
            end
        end
    end

    @test_throws ErrorException f()
end

# Neither can you continue repeatedly.
@testset MBTestSet "multiple continue" begin
    @multibreak function f()
        for i = 1:5
            for j = 1:3
                for k = 1:2
                    if i + j + k > 5
                        break; continue; continue
                    end
                end
            end
        end
    end

    @test_throws ErrorException f()
end

# For clarity, breaking cannot pass function call boundaries.
@testset MBTestSet "cannot break through function barrier" begin
    @multibreak function f()
        for i = 1:5
            for j = 1:3
                break; break; break
            end
        end
    end

    # Calling `f` gives an error rather than breaking the `k` loop.
    for k = 1:2
        @test_throws ErrorException f()
    end
end

# Note, in sufficiently simple cases, nested loops can be written as a
# single for statement with multiple variables. In that case a single
# `break` breaks out of all the loops whereas a single `continue`
# continues the inner loop. If that is enough, there is no need to
# involve the `@multibreak` macro.
@testset MBTestSet "single loop with multiple variables" begin
    n = 0
    for i = 1:5, j = 1:3
        n += 1
        if i + j > 5
            break
        end
    end
    @test n == 9

    n = 0
    for i = 1:5, j = 1:3
        n += 1
        if i + j > 5
            continue
        end
    end
    @test n == 15
end

# Naturally for loops with multiple variables can in turn be nested,
# in which case the `@multibreak` macro can be utilized.
@testset MBTestSet "nested loops with multiple variables" begin
    n = 0
    @multibreak begin
        for i = 1:3, j = 1:3
            for k = 1:3, l = 1:3
                n += 1
                if i + j + k + l > 6
                    break; break
                end
                if i + j + k + l > 5
                    break; continue
                end
            end
        end
    end
    @test n == 10
end

# So there's also a kind of loop called `while`, huh? We had better try
# that as well.
@testset MBTestSet "nested while loops" begin
    n = 0

    @multibreak begin
        while true
            while true
                n += 1
                break; break
            end
        end
    end
    @test n == 1

    @multibreak begin
        i = 0
        while i <= 5
            i += 1
            j = 1
            while j <= 3
                n += 1
                if i + j > 4
                    break; continue
                end
                j += 1
            end
            i += 1
        end
    end
    @test n == 9
end

# `for` and `while` loops can be mixed.
@testset MBTestSet "mixed for and while loops" begin
    n = 0

    @multibreak begin
        i = 1
        while i <= 3
            i += 1
            for j = i:5
                n += 1
                if i + j > 7
                    break; break
                end
                if i + j > 5
                    break; continue
                end
            end
        end
    end
    @test n == 5
end

# A word of warning. The `@multibreak` macro also transforms single
# `break` and `continue` to `@goto` and `@label`. A side effect of the
# implementation is that dead code can come alive. The macro could be
# refined to place the `@goto` at the position of the first
# `break`/`continue` rather than at the end of the block but it's not
# really worth the added complexity. Just don't do this in code where
# you need the `@multibreak`.
@testset MBTestSet "zombie code" begin
    I_am_a_zombie = false

    @multibreak begin
        while true
            break
            I_am_a_zombie = true
        end
    end
    @test I_am_a_zombie
end
