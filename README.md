
# WrappedUnions.jl

[![Build Status](https://github.com/Tortar/WrappedUnions.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/Tortar/WrappedUnions.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/Tortar/WrappedUnions.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/Tortar/WrappedUnions.jl)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

This package defines a minimalistic interface to work efficiently with Unions of types by wrapping them in a struct
to enhance function calls with enforced union-splitting.

## Example

```julia
julia> using WrappedUnions

julia> @wrapped struct X <: WrappedUnion
           union::Union{Bool, Int, Vector{Bool}, Vector{Int}}
       end

julia> xs = [X(false), X(1), X([true, false]), X([1,2])]
4-element Vector{X}:
 X(false)
 X(1)
 X(Bool[1, 0])
 X([1, 2])

julia> splittedsum(x) = @unionsplit sum(x)
splittedsum (generic function with 1 method)

julia> splittedsum.(xs)
4-element Vector{Int64}:
 0
 1
 1
 3

julia> unwrap(xs[3])
2-element Vector{Bool}:
 1
 0

julia> iswrappedunion(typeof(xs[1]))
true

julia> wrappedtypes(typeof(xs[1]))
(Bool, Int64, Vector{Bool}, Vector{Int64})
```

Let's verify that `splittedsum` has been accurately inferred:

```julia
julia> @code_warntype splittedsum.(xs)
MethodInstance for (::var"##dotfunction#230#1")(::Vector{X})
  from (::var"##dotfunction#230#1")(x1) @ Main none:0
Arguments
  #self#::Core.Const(var"##dotfunction#230#1"())
  x1::Vector{X}
Body::Vector{Int64}
1 ─ %1 = Base.broadcasted(Main.splittedsum, x1)::Base.Broadcast.Broadcasted{Base.Broadcast.DefaultArrayStyle{1}, Nothing, typeof(splittedsum), Tuple{Vector{X}}}
│   %2 = Base.materialize(%1)::Vector{Int64}
└──      return %2
```

`@unionsplit` allows to easily forward calls for `getproperty` or `setproperty!` or any other function

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

## API

```
- WrappedUnion                           -> Abstract type all new wrapped union are 
                                            subtype of.

- @wrapped struct ... end                -> Creates a wrapped union.

- unionsplit(f::Function, args::Tuple)   -> Executes the function performing union-splitting
                                            on the wrapped union arguments.

- @unionsplit f(args...)                 -> Calls `unionsplit(f, args)`.

- unwrap(::WrappedUnion)                 -> Returns the instance contained in the wrapped
                                            union.

- iswrappedunion(::Type{T})              -> Returns true if the type is a wrapped union.

- wrappedtypes(::Type{<:WrappedUnion})   -> Returns the types composing the wrapped union.
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
