import Mads

Mads.mads@info("TEST Saltelli sensitivity analysis:")
md = Mads.loadmadsfile("exec.mads")
results = Mads.saltelli(md, N=100)
results = Mads.saltelliparallel(md, N=50, 2)
Mads.printSAresults(md, results)
