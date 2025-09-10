
module WrappedUnions

export WrappedUnion, iswrappedunion, wrappedtypes, unwrap, unionsplit, @unionsplit, @wrapped

abstract type WrappedUnion end

macro wrapped(expr)
    (expr.head != :struct || expr.args[1] != false) && error("Expression is not an immutable struct")
    type = expr.args[2].args[1]
    type_name = type isa Symbol ? type : type.args[1]
    type_params = type isa Expr && type.head == :curly ? type.args[2:end] : []
    type_params_unconstr = [(t isa Symbol ? t : t.args[1]) for t in type_params]
    abstract_type = (expr.args[2] isa Symbol || expr.args[2].head != :<:) ? :Any : expr.args[2].args[2]
    abstract_type_name = abstract_type isa Symbol ? abstract_type : abstract_type.args[1]
    fields = Base.remove_linenums!(expr.args[3]).args
    if length(fields) != 1 || fields[1].args[1] != :union || fields[1].args[2].args[1] != :Union
        error("Struct should contain a unique field union::Union{...}")
    end
    union_types = fields[1].args[2].args[2:end]
    return esc(quote
        !($abstract_type <: $WrappedUnion) && error("Abstract type of struct should be a subtype of WrappedUnion")
        $expr
        if !isempty($type_params_unconstr)
            wrappedtypes(wu::Type{$type_name{$(type_params_unconstr...)}}) where {$(type_params...)} = ($(union_types...),)
        else
            wrappedtypes(wu::Type{$type_name}) = ($(union_types...),)
        end
        nothing
    end)
end

macro unionsplit(expr)
    expr.head != :call && error("Expression is not a function call")
    f, args = expr.args[1], expr.args[2:end]
    return esc(quote $WrappedUnions.unionsplit($f, ($(args...),)) end)
end

@generated function unionsplit(f::F, args::Tuple) where {F}
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

iswrappedunion(::Any) = false
iswrappedunion(::Type{<:WrappedUnion}) = true

unwrap(wu::WrappedUnion) = getfield(wu, :union)

end
