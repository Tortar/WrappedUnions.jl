
using WrappedUnions

using Aqua, Test

"docstring"
@wrapped struct K 
    union::Union{Int}
end

@wrapped struct X{Z}
    union::Union{Z, Int, Vector{Bool}, Vector{Int}}
end

splittedsum(x) = @unionsplit sum(x)

abstract type AbstractY <: WrappedUnion end
@wrapped mutable struct Y{A,B} <: AbstractY
    union::Union{A, B, Int64}
    Y{A,B}(x) where {A,B} = new{A,B}(x)
    Y(x::X) where X = new{typeof(x), Float64}(x)
end

sumt(x, y, z; q, t) = sum(x) + y + sum(z) + sum(q) + t
splittedsum(x::Y{A,B}, y, z::X; q::X, t) where {A,B} = @unionsplit sumt(x, y, z; q, t)

@wrapped struct OpenUnion{U}
    union::U
end

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
    isdefined(Docs, :hasdoc) && @test Docs.hasdoc(@__MODULE__, :K)

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

    ys = [Y{Vector{Int}, Vector{Bool}}(1), Y{Vector{Int}, Vector{Bool}}(2), Y{Vector{Int}, Vector{Bool}}([true, true]), Y{Vector{Int}, Vector{Bool}}([1,2])]

    @test Y <: AbstractY && AbstractY <: WrappedUnion
    @test typeof(ys) == Vector{Y{Vector{Int}, Vector{Bool}}}
    @test splittedsum.(ys, 2, xs; q=xs[2], t=1) == [5, 7, 7, 10]
    @test unwrap(ys[1]) == 1
    @test iswrappedunion(typeof(ys[1])) == true
    @test uniontype(typeof(ys[1])) == Union{Vector{Int}, Vector{Bool}, Int64}

    setfield!(ys[1], 1, [true, true])
    setfield!(ys[3], 1, 1)

    @test splittedsum.(ys, 2, xs; q=xs[2], t=1) == [6, 7, 6, 10]
    @test unwrap(ys[1]) == [true, true]
    @test iswrappedunion(typeof(ys[1])) == true
    @test uniontype(typeof(ys[1])) == Union{Vector{Int}, Vector{Bool}, Int64}

    @inferred Int splittedsum(ys[1], 2, xs[1]; q=xs[1], t=1)
    f(ys, z, xs) = splittedsum.(xs)
    @inferred Vector{Int} f(ys, 2, xs)

    @test iswrappedunion(OpenUnion{Union{Nothing, Char, Int, Float64}})

    ou = OpenUnion{Union{Nothing, Char, Int, Float64}}('c')
    @test unwrap(ou) == 'c'
    @test uniontype(ou) == Union{Nothing, Char, Int, Float64}

    ou2 = OpenUnion{Union{Nothing, Char, Int, Float64}}(5)
    @test unwrap(ou2) == 5
    @test uniontype(ou2) == Union{Nothing, Char, Int, Float64}

    @testset "Recursive union splitting" begin
        # Define nested wrapped unions
        @wrapped struct Inner
            union::Union{Int, Float64}
        end

        @wrapped struct Outer
            union::Union{Inner, String}
        end

        # Test helper function
        process(x::Int) = x * 2
        process(x::Float64) = x * 2.0
        process(x::String) = length(x)

        # Functions with recursive and non-recursive splitting
        process_recursive(x) = @unionsplit recursive=true process(x)
        process_nonrecursive(x) = @unionsplit process(x)

        # Create test instances
        inner_int = Inner(5)
        inner_float = Inner(3.14)
        outer_int = Outer(inner_int)
        outer_float = Outer(inner_float)
        outer_str = Outer("hello")

        # Test recursive splitting - should unwrap nested unions
        @test process_recursive(outer_int) == 10
        @test process_recursive(outer_float) == 6.28
        @test process_recursive(outer_str) == 5

        # Test non-recursive splitting - should only unwrap one level
        @test process_nonrecursive(outer_str) == 5
        # Non-recursive should fail on nested wrapped unions (no method for Inner)
        @test_throws MethodError process_nonrecursive(outer_int)

        # Test type stability for recursive splitting
        @inferred Int process_recursive(outer_int)
        @inferred Float64 process_recursive(outer_float)
        @inferred Int process_recursive(outer_str)

        # Test with multiple nested wrapped unions
        @wrapped struct Level3
            union::Union{Inner, Float64}
        end

        @wrapped struct Level4
            union::Union{Level3, String}
        end

        triple(x::Int) = x * 3
        triple(x::Float64) = x * 3.0
        triple(x::String) = x ^ 3  # Repeat string 3 times

        triple_recursive(x) = @unionsplit recursive=true triple(x)

        level3_inner = Level3(Inner(7))
        level3_float = Level3(2.5)
        level4_nested = Level4(level3_inner)
        level4_float = Level4(level3_float)
        level4_str = Level4("abc")

        @test triple_recursive(level4_nested) == 21
        @test triple_recursive(level4_float) == 7.5
        @test triple_recursive(level4_str) == "abcabcabc"
    end
end
