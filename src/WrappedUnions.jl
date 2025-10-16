
module WrappedUnions

export WrappedUnion, iswrappedunion, uniontype, unwrap, unionsplit, @unionsplit, @wrapped

const __FIELDNAME__ = gensym(:_union)

"""
    WrappedUnion <: Any

Abstract type which could be optionally used as a supertype of
wrapped unions.
"""
abstract type WrappedUnion end

"""
    @wrapped struct Name{Params...} <: AbstractType
        union::Union{Types...}
        InnerConstructors...
    end

Creates a wrapped union. `expr` must be a standard struct
instantiation syntax, e.g. inner constructors can be arbitrary.
However, it accepts only structs with a single field which must
be `union::Union{...}`.
"""
macro wrapped(expr)
    return esc(wrapped(expr))
end

function wrapped(expr)
    expr.head != :struct && error("Expression is not a struct")

    fields = Base.remove_linenums!(expr.args[3]).args
    union = expr.args[end].args[1].head != :const ? fields[1] : fields[1].args[1]

    if union.args[1] != :union
        error("Struct should contain a field named `union`")
    end
    args = expr.args[end].args[1].args
    args = expr.args[end].args[1].head == :(::) ? args : args[1].args
    args[1] = __FIELDNAME__

    return quote
        Core.@__doc__ $expr
    end
end

"""
    iswrappedunion(::Type)

Returns true if the type is a wrapped union.
"""
function iswrappedunion(::Type{T}) where T
    return isstructtype(T) && fieldcount(T) == 1 && fieldname(T, 1) == __FIELDNAME__
end

"""
    @unionsplit f(args...; kwargs...)

Calls `unionsplit(f, args, kwargs)`. See its docstring for further information.
"""
macro unionsplit(expr)
    expr.head != :call && error("Expression is not a function call")
    f = expr.args[1]
    if expr.args[2] isa Expr && expr.args[2].head == :parameters
        pos_args, kw_args = expr.args[3:end], expr.args[2].args
    else
        pos_args, kw_args = expr.args[2:end], []
    end
    return esc(quote
        $WrappedUnions.unionsplit($f, ($(pos_args...),), (;$(kw_args...)))
    end)
end


"""
    unionsplit(f::Union{Type,Function}, args::Tuple, kwargs::NamedTuple)

Executes the function performing union-splitting on the wrapped union arguments
passed as either positional `args` or keyword `kwargs`. This means that if the
function has a unique return type for each combination of unwrapped types, the
call will be type-stable.
"""
@generated function unionsplit(f::F, args::Tuple, kwargs::NamedTuple) where {F}
    pos_arg_types = fieldtypes(args)
    kw_arg_types = fieldtypes(kwargs)
    kw_arg_names = fieldnames(kwargs)

    # Find the leftmost wrapped union argument
    leftmost_wrapped = nothing

    # Check positional arguments first
    for (i, T) in enumerate(pos_arg_types)
        if iswrappedunion(T)
            leftmost_wrapped = (:pos, i, T)
            break
        end
    end

    # If not in positional, check keyword arguments
    if isnothing(leftmost_wrapped)
        for (i, T) in enumerate(kw_arg_types)
            if iswrappedunion(T)
                leftmost_wrapped = (:kw, kw_arg_names[i], T)
                break
            end
        end
    end

    # Base case: no wrapped unions found, just call the function
    if isnothing(leftmost_wrapped)
        func = iswrappedunion(F) ? :(unwrap(f)) : :f
        pos_args_expr = [:(args[$i]) for i in 1:length(pos_arg_types)]
        kw_args_expr = [Expr(:kw, name, :(kwargs.$name)) for name in kw_arg_names]
        return :($func($(pos_args_expr...); $(kw_args_expr...)))
    end

    # Recursive step: split the leftmost wrapped union
    source, id, T = leftmost_wrapped
    wrapped_types = Base.uniontypes(fieldtype(T, 1))

    unwrapped_var = gensym(:unwrapped)
    original_arg = source == :pos ? :(args[$id]) : :(kwargs.$id)

    # Build the if/elseif/.../else chain
    branch_expr = :(error("No branch matched. This should be unreachable."))

    # For each possible type in the union, create a new set of arguments
    # for the recursive call, with the current argument unwrapped.
    new_pos_args = Any[:(args[$i]) for i in 1:length(pos_arg_types)]
    new_kw_args_map = Dict{Any, Any}(name => :(kwargs.$name) for name in kw_arg_names)

    for V_type in reverse(wrapped_types)

        if source == :pos
            new_pos_args[id] = unwrapped_var
        else
            new_kw_args_map[id] = unwrapped_var
        end

        new_kw_args = [Expr(:kw, name, val) for (name, val) in new_kw_args_map]
        
        # The body of the branch is the recursive call
        recursive_call = :($WrappedUnions.unionsplit(f, ($(new_pos_args...),), (;$(new_kw_args...))))
        condition = :($unwrapped_var isa $V_type)
        branch_expr = Expr(:elseif, condition, recursive_call, branch_expr)
    end
    
    # The first `elseif` needs to be an `if`
    branch_expr = Expr(:if, branch_expr.args...)

    # The final generated code unwraps the argument and runs the conditional logic
    body = quote
        $unwrapped_var = unwrap($original_arg)
        $branch_expr
    end
    return body
end

"""
    unwrap(wu)

Returns the instance contained in the wrapped union.
"""
unwrap(wu) = getfield(wu, __FIELDNAME__)

"""
    uniontype(::Type)

Returns the union type inside the wrapped union.
"""
uniontype(T::Type) = fieldtype(T, __FIELDNAME__)
uniontype(::T) where {T} = uniontype(T)

precompile(wrapped, (Expr,))

end
