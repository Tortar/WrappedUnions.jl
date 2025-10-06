
using WrappedUnions

using Aqua, Test

@wrapped struct K 
    union::Union{Int}
end

@wrapped struct X{Z}
    union::Union{Z, Int, Vector{Bool}, Vector{Int}}
end

splittedsum(x) = @unionsplit sum(x)

abstract type AbstractY <: WrappedUnion end
@wrapped mutable struct Y{A,B} <: AbstractY
    const union::Union{A, B, Int64}
    Y{A,B}(x) where {A,B} = new{A,B}(x)
    Y(x::X) where X = new{typeof(x), Float64}(x)
end

sumt(x, y, z; q, t) = sum(x) + y + sum(z) + sum(q) + t
splittedsum(x::Y{A,B}, y, z::X; q::X, t) where {A,B} = @unionsplit sumt(x, y, z; q, t)

@testset "WrappedUnions.jl" begin
    
    if "CI" in keys(ENV)
        @testset "Code quality (Aqua.jl)" begin
            Aqua.test_all(WrappedUnions, deps_compat=false)
            Aqua.test_deps_compat(WrappedUnions, check_extras=false)
        end
    end

    @test iswrappedunion(Int) == false

    k = K(1)

    @test !(K <: WrappedUnion)
    @test typeof(k) == K
    @test splittedsum(k) == 1
    @test unwrap(k) == 1
    @test iswrappedunion(typeof(k)) == true
    @test uniontype(typeof(k)) == Union{Int}

    xs = [X{Bool}(false), X{Bool}(1), X{Bool}([true, false]), X{Bool}([1,2])]

    @test !(X <: WrappedUnion)
    @test typeof(xs) == Vector{X{Bool}}
    @test splittedsum.(xs) == [0, 1, 1, 3]
    @test unwrap(xs[3]) == [true, false]
    @test iswrappedunion(typeof(xs[1])) == true
    @test uniontype(typeof(xs[1])) == Union{Bool, Int, Vector{Bool}, Vector{Int}}

    @inferred Int splittedsum(xs[1])
    f(xs) = splittedsum.(xs)
    @inferred Vector{Int} f(xs)

    ys = [Y{Vector{Int}, Vector{Bool}}(1), Y{Vector{Int}, Vector{Bool}}(2), Y{Vector{Int}, Vector{Bool}}([true, false]), Y{Vector{Int}, Vector{Bool}}([1,2])]

    @test Y <: AbstractY && AbstractY <: WrappedUnion
    @test typeof(ys) == Vector{Y{Vector{Int}, Vector{Bool}}}
    @test splittedsum.(ys, 2, xs; q=xs[2], t=1) == [5, 7, 6, 10]
    @test unwrap(ys[1]) == 1
    @test iswrappedunion(typeof(ys[1])) == true
    @test uniontype(typeof(ys[1])) == Union{Vector{Int}, Vector{Bool}, Int64}

    @inferred Int splittedsum(ys[1], 2, xs[1]; q=xs[1], t=1)
    f(ys, z, xs) = splittedsum.(xs)
    @inferred Vector{Int} f(ys, 2, xs)
end
