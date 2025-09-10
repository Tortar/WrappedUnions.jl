# WrappedUnions.jl
Wrap a Union and Enjoy Type-Stability

Interface Idea:

```julia
@Name(Types...) [<: WrappedUnion]
unwrap
iswrappedunion
wrappedtypes
branch
```

with no method defined apart from constructors by default and no dependency
apart from Julia.
