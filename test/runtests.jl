using Test

# Customize the testset slightly to line up the output.
struct MBTestSet <: Test.AbstractTestSet end
MBTestSet(description) = Test.DefaultTestSet(rpad(description, 50))

include("tutorial.jl")
