
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
    @wrapped struct Name{Params...} <: SubTypeWrappedUnion
        union::Union{Types...}
        InnerConstructors...
    end

Creates a wrapped union. `expr` must be a standard struct
instantiation syntax, e.g. inner constructors can be arbitrary.
However, it accepts only structs with a single field which must
be `union::Union{...}` and whose abstract type is a subtype of
`WrappedUnion`.
"""
macro wrapped(expr)
    return esc(wrapped(expr))
end

function wrapped(expr)
    expr.head != :struct && error("Expression is not a struct")
    type = (expr.args[2] isa Symbol || expr.args[2].head != :<:) ? expr.args[2] : expr.args[2].args[1]
    type_name = type isa Symbol ? type : type.args[1]
    type_params = type isa Expr && type.head == :curly ? type.args[2:end] : []
    type_params_unconstr = [(t isa Symbol ? t : t.args[1]) for t in type_params]
    fields = Base.remove_linenums!(expr.args[3]).args
    expr.args[1] == true && fields[1].head != :const && error("union field should be constant in a mutable struct")
    union = expr.args[1] == false ? fields[1] : fields[1].args[1]
    if union.args[1] != :union || union.args[2].args[1] != :Union
        error("Struct should contain a unique field union::Union{...}")
    end
    expr.args[end].args[1].args[1] = __FIELDNAME__
    return quote
        $expr
        if !isempty($type_params_unconstr)
            uniontype(wu::Type{$type_name{$(type_params_unconstr...)}}) where {$(type_params...)} = $(union.args[2])
        else
            uniontype(wu::Type{$type_name}) = $(union.args[2])
        end
        nothing
    end
end

"""
    iswrappedunion(::Type{T})

Returns true if the type is a wrapped union.
"""
function iswrappedunion(::Type{T}) where T
    return isstructtype(T) && fieldcount(T) == 1 && fieldname(T, 1) == __FIELDNAME__
end

"""
    @unionsplit f(args...)

Calls `unionsplit(f, args)`. See its docstring for further information.
"""
macro unionsplit(expr)
    expr.head != :call && error("Expression is not a function call")
    f, args = expr.args[1], expr.args[2:end]
    return esc(quote $WrappedUnions.unionsplit($f, ($(args...),)) end)
end

"""
    unionsplit(f::Union{Type,Function}, args::Tuple)

Executes the function performing union-splitting on the wrapped union arguments.
This means that if the function has a unique return type, the function call will
be type-stable.
"""
@generated function unionsplit(f::F, args::Tuple) where {F}
    args = fieldtypes(args)
    wrappedunion_args = [(i, T) for (i, T) in enumerate(args) if iswrappedunion(T)]
    final_args = Any[:(args[$i]) for i in 1:length(args)]
    for (idx, T) in wrappedunion_args
        final_args[idx] = Symbol("v_", idx)
    end
    
    func = iswrappedunion(F) ? :(unwrap(f)) : (:f)
    body = :($func($(final_args...)))
    for (idx, T) in reverse(wrappedunion_args)
        unwrapped_var = Symbol("v_", idx)
        wrapped_types = Base.uniontypes(fieldtype(T, 1))
        
        branch_expr = :(error("THIS_SHOULD_BE_UNREACHABLE"))
        for V_type in reverse(wrapped_types)
            condition = :($unwrapped_var isa $V_type)
            branch_expr = Expr(:elseif, condition, body, branch_expr)
        end
        branch_expr = Expr(:if, branch_expr.args...)
        
        body = quote
            let $(unwrapped_var) = unwrap(args[$idx])
                $branch_expr
            end
        end
    end
    return body
end

"""
    unwrap(wu::WrappedUnion)

Returns the instance contained in the wrapped union.
"""
unwrap(wu) = getfield(wu, __FIELDNAME__)

"""
    uniontype(::Type)

Returns the union type inside the wrapped union.
"""
function uniontype end

precompile(wrapped, (Expr,))

end
