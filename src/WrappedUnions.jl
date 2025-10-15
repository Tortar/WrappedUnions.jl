
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
    @unionsplit [recursive=false] f(args...; kwargs...)

Calls `unionsplit(f, args, kwargs; recursive=recursive)`. See its docstring for further information.

The optional `recursive` parameter can be specified as `@unionsplit recursive=true f(...)`.
"""
macro unionsplit(expr)
    if expr.head == :(=) && expr.args[1] == :recursive
        # Handle @unionsplit recursive=true/false f(...)
        recursive = expr.args[2]
        call_expr = nothing
        return esc(quote
            error("@unionsplit recursive=... syntax requires a function call after it")
        end)
    elseif expr.head != :call
        error("Expression is not a function call")
    end
    
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

# Two-argument version for recursive parameter
macro unionsplit(recursive_expr, call_expr)
    if recursive_expr.head != :(=) || recursive_expr.args[1] != :recursive
        error("First argument must be recursive=true or recursive=false")
    end
    recursive = recursive_expr.args[2]
    
    if call_expr.head != :call
        error("Second argument must be a function call")
    end
    
    f = call_expr.args[1]
    if call_expr.args[2] isa Expr && call_expr.args[2].head == :parameters
        pos_args, kw_args = call_expr.args[3:end], call_expr.args[2].args
    else
        pos_args, kw_args = call_expr.args[2:end], []
    end
    return esc(quote
        $WrappedUnions.unionsplit($f, ($(pos_args...),), (;$(kw_args...)); recursive=$recursive)
    end)
end


"""
    unionsplit(f::Union{Type,Function}, args::Tuple, kwargs::NamedTuple; recursive::Bool=false)

Executes the function performing union-splitting on the wrapped union arguments
passed as either positional `args` or keyword `kwargs`. This means that if the
function has a unique return type for each combination of unwrapped types, the
call will be type-stable.

If `recursive=true`, wrapped unions nested within other wrapped unions will be 
recursively unwrapped. This allows handling cases where a wrapped union contains
other wrapped unions.
"""
function unionsplit(f::F, args::Tuple, kwargs::NamedTuple; recursive::Bool=false) where {F}
    if recursive
        return unionsplit(Val(true), f, args, kwargs)
    else
        return unionsplit(Val(false), f, args, kwargs)
    end
end

@generated function unionsplit(::Val{RECURSIVE}, f::F, args::Tuple, kwargs::NamedTuple) where {RECURSIVE, F}
    pos_arg_types = fieldtypes(args)
    kw_arg_types = fieldtypes(kwargs)
    kw_arg_names = fieldnames(kwargs)
    
    # Helper function to recursively collect wrapped union types
    function collect_wrapped_types(T, recursive_flag)
        if !iswrappedunion(T)
            return [T]
        end
        inner_union = fieldtype(T, 1)
        union_types = Base.uniontypes(inner_union)
        if !recursive_flag
            return union_types
        end
        # Recursively expand any wrapped unions within the union
        result = []
        for U in union_types
            if iswrappedunion(U)
                append!(result, collect_wrapped_types(U, true))
            else
                push!(result, U)
            end
        end
        return result
    end
    
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
        wrapped_types = collect_wrapped_types(T, RECURSIVE)
        branch_expr = :(error("THIS_SHOULD_BE_UNREACHABLE"))
        for V_type in reverse(wrapped_types)
            condition = :($unwrapped_var isa $V_type)
            branch_expr = Expr(:elseif, condition, body, branch_expr)
        end
        branch_expr = Expr(:if, branch_expr.args...)
        if RECURSIVE
            # For recursive mode, we need to recursively unwrap
            body = quote
                $unwrapped_var = unwrap($original_arg)
                while iswrappedunion(typeof($unwrapped_var))
                    $unwrapped_var = unwrap($unwrapped_var)
                end
                $branch_expr
            end
        else
            body = quote
                $unwrapped_var = unwrap($original_arg)
                $branch_expr
            end
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
