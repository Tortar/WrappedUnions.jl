
using WrappedUnions

using Aqua, Test

@testset "WrappedUnions.jl" begin

    if "CI" in keys(ENV)
        @testset "Code quality (Aqua.jl)" begin
            Aqua.test_all(WrappedUnions, deps_compat=false)
            Aqua.test_deps_compat(WrappedUnions, check_extras=false)
        end
    end
end
