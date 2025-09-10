# WrappedUnions.jl
Wrap a Union and Enjoy Type-Stability

Interface Idea:

```julia
@wrapped struct #Name [<: WrappedUnion] # let's say Name = WU
    union::Union{...}
    #constructors
end
unwrap(w::WU)
iswrappedunion(w::WU)
wrappedtypes(w::WU)
branch(f::Function, args::Tuple)
@branch f(args)
```

with no method defined apart from constructors by default and no dependency
apart from Julia.
