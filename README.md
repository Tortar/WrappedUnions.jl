
# WrappedUnions.jl

[![Build Status](https://github.com/Tortar/WrappedUnions.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/Tortar/WrappedUnions.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/Tortar/WrappedUnions.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/Tortar/WrappedUnions.jl)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

This package offers a minimal interface to work efficiently with a `Union` of types wrapped into a struct
by allowing to enforce union-splitting at call site.

Two main macro provide the backbone of this package: `@wrapped` and `@unionsplit`. The first accept any
parametric struct which has a single fields `union::Union` and whose abstract type is a subtype of 
`WrappedUnion`, apart from that, it supports any standard struct feature as e.g. inner constructors.
`@unionsplit` instead automatically executes a function performing union-splitting on the wrapped union
arguments to make the call type-stable.

## Examples

```julia
julia> using WrappedUnions

julia> @wrapped struct X <: WrappedUnion
           union::Union{Bool, Int, Vector{Bool}, Vector{Int}}
       end

julia> xs = (X(false), X(1), X([true, false]), X([1,2]))
(X(false), X(1), X(Bool[1, 0]), X([1, 2]))

julia> splitsum(x) = @unionsplit sum(x)
splittedsum (generic function with 1 method)

julia> splitsum.(xs)
(0, 1, 1, 3)

julia> unwrap(xs[3])
2-element Vector{Bool}:
 1
 0

julia> iswrappedunion(typeof(xs[1]))
true

julia> wrappedtypes(typeof(xs[1]))
(Bool, Int64, Vector{Bool}, Vector{Int64})
```

Let's verify that `splitsum` has been accurately inferred:

```julia
julia> @code_warntype splitsum.(xs)
MethodInstance for (::var"##dotfunction#230#1")(::NTuple{4, X})
  from (::var"##dotfunction#230#1")(x1) @ Main none:0
Arguments
  #self#::Core.Const(var"##dotfunction#230#1"())
  x1::NTuple{4, X}
Body::NTuple{4, Int64}
1 ─ %1 = Base.broadcasted(Main.splitsum, x1)::Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple}, Nothing, typeof(splitsum), Tuple{NTuple{4, X}}}
│   %2 = Base.materialize(%1)::NTuple{4, Int64}
└──      return %2
```

What if we used just

```julia
julia> xs = (false, 1, [true, false], [1,2])
(false, 1, Bool[1, 0], [1, 2])
```

then

```julia
julia> @code_warntype sum.(xs)
MethodInstance for (::var"##dotfunction#230#1")(::Tuple{Bool, Int64, Vector{Bool}, Vector{Int64}})
  from (::var"##dotfunction#230#1")(x1) @ Main none:0
Arguments
  #self#::Core.Const(var"##dotfunction#230#1"())
  x1::Tuple{Bool, Int64, Vector{Bool}, Vector{Int64}}
Body::NTuple{4, Any}
1 ─ %1 = Main.sum::Core.Const(sum)
│   %2 = Base.broadcasted(%1, x1)::Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple}, Nothing, typeof(sum), Tuple{Tuple{Bool, Int64, Vector{Bool}, Vector{Int64}}}}
│   %3 = Base.materialize(%2)::NTuple{4, Any}
└──      return %3
```

Notice the `NTuple{4, Any}` instead of `NTuple{4, Int64}`.

Consider also that `@unionsplit` allows to easily forward calls of any function, such as `getproperty` or `setproperty!`
as shown below

```julia
julia> using WrappedUnions

julia> mutable struct A x::Int end

julia> mutable struct B x::Int end

julia> @wrapped struct Y <: WrappedUnion
           union::Union{A, B}
       end

julia> Base.getproperty(y::Y, name::Symbol) = @unionsplit Base.getproperty(y, name)

julia> Base.setproperty!(y::Y, name::Symbol, x) = @unionsplit Base.setproperty!(y, name, x)

julia> y = Y(A(1))
Y(A(1))

julia> y.x
1

julia> y.x = 2
2
```

What if the function is inherently type-unstable? Well, just use another wrapped
union as output!

```julia
julia> @wrapped struct Z <: WrappedUnion
           union::Union{Float64, Vector{Float64}}
       end

julia> f(x) = x / true;

julia> f(x::X) = Z(@unionsplit f(x));

julia> xs = (X(false), X(1), X([true, false]), X([1,2]))
(X(false), X(1), X(Bool[1, 0]), X([1, 2]))

julia> f.(xs) # this is now type-stable
(Z(0.0), Z(1.0), Z([1.0, 0.0]), Z([1.0, 2.0]))
```

## API

```
- WrappedUnion                                     -> Abstract type all new wrapped union are 
                                                      subtype of.

- @wrapped struct ... end                          -> Creates a wrapped union.

- unionsplit(f::Union{Type,Function}, args::Tuple) -> Executes the function performing union-splitting
                                                      on the wrapped union arguments.

- @unionsplit f(args...)                           -> Calls `unionsplit(f, args)`.

- unwrap(::WrappedUnion)                           -> Returns the instance contained in the wrapped
                                                      union.

- iswrappedunion(::Type{T})                        -> Returns true if the type is a wrapped union.

- wrappedtypes(::Type{<:WrappedUnion})             -> Returns the types composing the wrapped union.
```

For more information, see the docstrings.

## Related Packages

These are packages with similar functionalities:

- [`LightSumTypes.jl`](https://github.com/JuliaDynamics/LightSumTypes.jl)
- [`SumTypes.jl`](https://github.com/MasonProtter/SumTypes.jl)
- [`Moshi.jl`](https://github.com/Roger-luo/Moshi.jl)
- [`Unityper.jl`](https://github.com/YingboMa/Unityper.jl)

Though, `WrappedUnions.jl` is the one offering, in the eye of its author, the most transparent, simple and flexible
interface.

## Contributing

Contributions are welcome! If you encounter any issues, have suggestions for improvements, or would like to add new features, feel free to open an issue or submit a pull request.
