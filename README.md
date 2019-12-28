# Multibreak.jl

Have you ever wanted a convenient way to break out of multiple nested
loops at once in your Julia code?

The Multibreak package provides the `@multibreak` macro, which allows
you to do exactly that. In this contrived but simple example, the
`break; break` line breaks out of both loops:

```
using Multibreak

@multibreak begin
    for i = 1:5
        if i % 3 > 0
            for j = 1:5
                @show i, j
                if (i + j^2) % 7 == 0
                    break; break
                end
            end
        end
    end
end
```

More generally the `@multibreak` macro allows you to `break` out of
any number of nested loops and optionally to `continue` the next
enclosing loop.

## Documentation

The tests are the documentation. The [tutorial](test/tutorial.jl) explores the
functionality provided by the `@multibreak` macro.

## Background

The `@multibreak` macro was first implemented as a
[gist](https://gist.github.com/GunnarFarneback/c970c9e63a33720bb71d0023f2c8a10f),
providing a proof of concept for a proposal in the Julia
[#5334](https://github.com/JuliaLang/julia/issues/5334#issuecomment-174475286)
issue. The proposed syntax differs by using comma instead of semicolon
between `break`/`continue`. The former is a syntax error in Julia 1.x,
whereas the latter is syntactically valid but semantically useless,
making it ideal for a macro implementation.
