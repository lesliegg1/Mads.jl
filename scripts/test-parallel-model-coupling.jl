import Distributed

include(joinpath(Mads.madsdir, "src", "MadsParallel.jl"))
@info("Set processors ...")
setprocs(ntasks_per_node=1)
@Distributed.everywhere display(ENV["PATH"])

@info("Import MADS ...")
import Mads
@Distributed.everywhere Mads.quietoff()

@info("Test MADS ... ")
Mads.test("model_coupling")
