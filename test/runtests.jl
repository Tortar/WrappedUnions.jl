
using WrappedUnions

using Aqua, Test

@testset "WrappedUnions.jl" begin

    if "CI" in keys(ENV)
        @testset "Code quality (Aqua.jl)" begin
            Aqua.test_all(WeightVectors, deps_compat=false)
            Aqua.test_deps_compat(WeightVectors, check_extras=false)
        end
    end
end
