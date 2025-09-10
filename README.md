
# WrappedUnions.jl

This package defines a minimalistic interface to work efficiently with Unions of types.

# Example

```julia
julia> using WrappedUnions

julia> @wrapped struct X <: WrappedUnion
           union::Union{Bool, Int, Vector{Bool}, Vector{Int}}
       end

julia> x = X([1,2])
X([1, 2])

julia> @split sum(x)
3

julia> unwrap(x)
2-element Vector{Int64}:
 1
 2

julia> iswrappedunion(typeof(x))
true

julia> wrappedtypes(typeof(x))
(Bool, Int64, Vector{Bool}, Vector{Int64})
```

# API

- `WrappedUnion`                           -> Abstract type all new wrapped union must be subtype of.
- `@wrapped struct ... end`                -> Creates a wrapped union.
- `@split f(args...)`                      -> Executes the function performing union-splitting on the 
                                              wrapped union arguments. 
- `unwrap(::WrappedUnion)`                 -> Returns the instance contained in the wrapped union.
- `iswrappedunion(::Type{<:WrappedUnion})` -> Returns true if the type is a wrapped union.
- `wrappedtypes(::Type{<:WrappedUnion})`   -> Returns the types composing the internal union.
