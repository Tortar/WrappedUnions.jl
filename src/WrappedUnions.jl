
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
    expr.args[1] == true && fields[1].head != :const && error("union field should be constant in a mutable struct")
    union = expr.args[1] == false ? fields[1] : fields[1].args[1]
    if union.args[1] != :union || union.args[2].args[1] != :Union
        error("Struct should contain a unique field union::Union{...}")
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
    wrappedunion_args = []
    for (i, T) in enumerate(pos_arg_types)
        if iswrappedunion(T)
            push!(wrappedunion_args, (:pos, i, T))
        end
    end
    for (i, T) in enumerate(kw_arg_types)
        if iswrappedunion(T)
            name = kw_arg_names[i]
            push!(wrappedunion_args, (:kw, name, T))
        end
    end
    final_pos_args = Any[:(args[$i]) for i in 1:length(pos_arg_types)]
    final_kw_args_map = Dict{Any, Any}(name => :(kwargs.$name) for name in kw_arg_names)
    for (source, id, T) in wrappedunion_args
        var_name = source == :pos ? Symbol("v_pos_", id) : Symbol("v_kw_", id)
        if source == :pos
            final_pos_args[id] = var_name
        else
            final_kw_args_map[id] = var_name
        end
    end
    final_kw_args = [Expr(:kw, name, val) for (name, val) in final_kw_args_map]
    func = iswrappedunion(F) ? :(unwrap(f)) : :f
    body = :($func($(final_pos_args...); $(final_kw_args...)))
    for (source, id, T) in reverse(wrappedunion_args)
        unwrapped_var = source == :pos ? Symbol("v_pos_", id) : Symbol("v_kw_", id)
        original_arg = source == :pos ? :(args[$id]) : :(kwargs.$id)
        wrapped_types = Base.uniontypes(fieldtype(T, 1))
        branch_expr = :(error("THIS_SHOULD_BE_UNREACHABLE"))
        for V_type in reverse(wrapped_types)
            condition = :($unwrapped_var isa $V_type)
            branch_expr = Expr(:elseif, condition, body, branch_expr)
        end
        branch_expr = Expr(:if, branch_expr.args...)
        body = quote
            $unwrapped_var = unwrap($original_arg)
            $branch_expr
        end
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
