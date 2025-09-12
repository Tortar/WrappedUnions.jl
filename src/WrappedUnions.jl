
module WrappedUnions

export WrappedUnion, iswrappedunion, wrappedtypes, unwrap, unionsplit, @unionsplit, @wrapped

"""
    WrappedUnion <: Any

Abstract type all new wrapped union are subtype of.
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
    abstract_type = (expr.args[2] isa Symbol || expr.args[2].head != :<:) ? :WrappedUnion : expr.args[2].args[2]
    abstract_type_name = abstract_type isa Symbol ? abstract_type : abstract_type.args[1]
    fields = Base.remove_linenums!(expr.args[3]).args
    expr.args[1] == true && fields[1].head != :const && error("union field should be constant in a mutable struct")
    union = expr.args[1] == false ? fields[1] : fields[1].args[1]
    union_types = unique(union.args[2].args[2:end])
    if union.args[1] != :union || union.args[2].args[1] != :Union
        error("Struct should contain a unique field union::Union{...}")
    end
    expr.args[2] = (expr.args[2] isa Symbol || expr.args[2].head != :<:) ? Expr(:(<:), expr.args[2], abstract_type) : expr.args[2]
    return quote
        !($abstract_type <: $WrappedUnion) && error("Abstract type of struct should be a subtype of WrappedUnion")
        $expr
        if !isempty($type_params_unconstr)
            wrappedtypes(wu::Type{$type_name{$(type_params_unconstr...)}}) where {$(type_params...)} = ($(union_types...),)
        else
            wrappedtypes(wu::Type{$type_name}) = ($(union_types...),)
        end
        nothing
    end
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
@generated function unionsplit(f::Union{Type,Function}, args::Tuple)
    args = fieldtypes(args)
    wrappedunion_args = [(i, T) for (i, T) in enumerate(args) if T <: WrappedUnion]
    final_args = Any[:(args[$i]) for i in 1:length(args)]
    for (idx, T) in wrappedunion_args
        final_args[idx] = Symbol("v_", idx)
    end
    
    body = :(f($(final_args...)))
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
    iswrappedunion(::Type{T})

Returns true if the type is a wrapped union.
"""
iswrappedunion(::Any) = false
iswrappedunion(::Type{<:WrappedUnion}) = true

"""
    unwrap(wu::WrappedUnion)

Returns the instance contained in the wrapped union.
"""
unwrap(wu::WrappedUnion) = getfield(wu, :union)

"""
    wrappedtypes(::Type{<:WrappedUnion})

Returns the types composing the wrapped union.
"""
function wrappedtypes end

precompile(wrapped, (Expr,))

end
