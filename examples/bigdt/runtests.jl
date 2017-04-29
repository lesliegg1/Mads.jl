import Mads
import JLD
using Base.Test

problemdir = Mads.getmadsdir()
workdir = joinpath(Mads.madsdir, "..", "examples", "bigdt")

if isdefined(:yaml)
	md = Mads.loadmadsfile(joinpath(problemdir, "source_termination.mads"))
else
	md = Mads.loadmadsfile(joinpath(problemdir, "source_termination_json.mads"), format="json")
end

nsample = 10
bigdt_results = Mads.dobigdt(md, nsample; maxHorizon = 0.8, numlikelihoods = 2)

if isdefined(:Gadfly)
	f = joinpath(problemdir, "source_termination-robustness-$nsample")
	Mads.plotrobustnesscurves(md, bigdt_results; filename=f)
	Mads.rmfiles_root(f)
end

# If enabled, save output as test file
if Mads.create_tests
    d = joinpath(workdir, "test_results")
    Mads.mkdir(d)

    JLD.save(joinpath(d, "bigdt_results.jld"), "bigdt_results", bigdt_results)
end

# Testing for bigdt 
@testset "Bigdt" begin
    good_bigdt_results = JLD.load(joinpath(workdir, "test_results", "bigdt_results.jld"), "bigdt_results")

    @test isapprox(bigdt_results["maxfailureprobs"], good_bigdt_results["maxfailureprobs"], atol=1e-6)
    @test isapprox(bigdt_results["horizons"], good_bigdt_results["horizons"], atol=1e-6)
end