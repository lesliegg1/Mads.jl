import Mads
import Base.Test

Mads.madsinfo("Monte Carlo analysis ...")
workdir = Mads.getmadsdir() # get the directory where the problem is executed
if workdir == ""
	workdir = joinpath(Mads.madsdir, "..", "examples", "montecarlo")
end

md = Mads.loadmadsfile(joinpath(workdir, "internal-linearmodel.mads"))
srand(2015)
results = Mads.montecarlo(md; N=10)

if Mads.create_tests
	d = joinpath(workdir, "test_results")
	Mads.mkdir(d)
	@JLD.save joinpath(d, "montecarlo.jld") results
end

good_results = JLD.load(joinpath(workdir, "test_results", "montecarlo.jld"), "results")
@Base.Test.test results == good_results

Mads.rmdir(joinpath(workdir, "..", "model_coupling", "internal-linearmodel_restart"))