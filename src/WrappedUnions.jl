
module WrappedUnions

abstract type WrappedUnion end

unwrap(wu::WrappedUnion) = getfield(wu, :union)

function _get_union_types(T_sum)
    field_T = fieldtype(T_sum, 1)
    types = []
    curr = field_T
    while curr isa Union
        push!(types, curr.a)
        curr = curr.b
    end
    push!(types, curr)
    return types
end

@generated function branch(f::F, args::Tuple) where {F}
    
    args = fieldtypes(args)
    wrappedunion_args = [(i, T) for (i, T) in enumerate(args) if T <: WrappedUnion]

    final_args = Any[:(args[$i]) for i in 1:length(args)]
    for (idx, T) in wrappedunion_args
        final_args[idx] = Symbol("v_", idx)
    end
    
    body = :(f($(final_args...)))
    
    for (idx, T) in reverse(wrappedunion_args)
        unwrapped_var = Symbol("v_", idx)
        wrapped_types = _get_union_types(T)
        
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

end
