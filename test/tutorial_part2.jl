# This part of the tutorial is only applicable when the Julia version
# is 1.14 or later.

# The initial example of multibreak in the first part of the tutorial was
#
# @multibreak begin
#     for i = 1:5
#         for j = 1:3
#             if i == 1 && j == 1
#                 continue
#             elseif i == 2 && j == 2
#                 break
#             elseif i == 3 && j == 2
#                 break; continue
#             elseif i == 4 && j == 2
#                 break; break
#             end
#             push!(out, (i, j))
#         end
#         push!(out, i)
#     end
# end
#
# With Julia >= 1.14 and Multibreak >= 1.0, this is effectively
# transformed into a labeled break/continue instead of label/goto.
# (Technically it is directly transformed to the same expression
# representation that labeled break/continue uses.)
#
# If you prefer that syntax over the Multibreak syntax, you can of
# course use it directly without the Multibreak package, provided that
# you do not support any Julia versions prior to 1.14.
@testset MBTestSet "labeled break and continue" begin
    out = []
    @label outer for i = 1:5
        for j = 1:3
            if i == 1 && j == 1
                continue
            elseif i == 2 && j == 2
                break
            elseif i == 3 && j == 2
                continue outer
            elseif i == 4 && j == 2
                break outer
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

# Labeled break/continue can be mixed with multibreak in the same
# code, even to refer to the same loop (although there is little
# reason to do that).
@testset MBTestSet "mixed multibreak with labeled break and continue" begin
    out = []
    @multibreak begin
        @label outer for i = 1:5
            for j = 1:3
                if i == 1 && j == 1
                    continue
                elseif i == 2 && j == 2
                    break
                elseif i == 3 && j == 2
                    continue outer
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

# However, labeled and unlabeled break cannot be combined into one
# multibreak expression.
@testset MBTestSet "mixed break and labeled break" begin
    @multibreak function f()
        @label _ for i = 1:5
            for j = 1:3
                break; break _
            end
        end
    end

    @test_throws ErrorException f()
end

# Same for continue.
@testset MBTestSet "mixed break and labeled continue" begin
    @multibreak function f()
        @label _ for i = 1:5
            for j = 1:3
                break; continue _
            end
        end
    end

    @test_throws ErrorException f()
end
