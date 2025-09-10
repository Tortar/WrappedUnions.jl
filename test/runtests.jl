
using WrappedUnions

using Aqua, Test

@wrapped struct X <: WrappedUnion
    union::Union{Bool, Int, Vector{Bool}, Vector{Int}}
end

splittedsum(x) = @unionsplit sum(x)

@testset "WrappedUnions.jl" begin
    
    if "CI" in keys(ENV)
        @testset "Code quality (Aqua.jl)" begin
            Aqua.test_all(WrappedUnions, deps_compat=false)
            Aqua.test_deps_compat(WrappedUnions, check_extras=false)
        end
    end

    xs = [X(false), X(1), X([true, false]), X([1,2])]

    @test X <: WrappedUnion
    @test typeof(xs) == Vector{X}
    @test splittedsum.(xs) == [0, 1, 1, 3]
    @test unwrap(xs[3]) == [true, false]
    @test iswrappedunion(typeof(xs[1])) == true
    @test wrappedtypes(typeof(xs[1])) == (Bool, Int64, Vector{Bool}, Vector{Int64})

    @inferred Int splittedsum(xs[1])
    f(xs) = splittedsum.(xs)
    @inferred Vector{Int} f(xs)
end
