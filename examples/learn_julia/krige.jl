import GeoStats
import PyPlot
import Gadfly

PyPlot.svg(true)

dim = 2
nobs = 20
X = rand(dim, nobs) # random observation locations
z = rand(nobs) # random observations

n = 101
x = collect(range(0; stop=1, length=n))
y = x

loc = Array{Float64}(undef, dim)
k = Array{Float64}(undef, n, n)
c = Array{Float64}(undef, n, n)
for i in 1:n
	loc[1] = x[i]
	for j in 1:n
		loc[2] = y[j]
		k[j, i], c[j, i] = GeoStats.kriging(loc, X, z)
	end
end

Gadfly.plot(Gadfly.layer(z=k, x=x, y=y, Gadfly.Geom.contour(levels=collect(range(minimum(k); stop=maximum(k), length=51)))), Gadfly.layer(x=X[1,:], y=X[2,:], Geom.point, Gadfly.Theme(default_color=parse(Colors.Colorant, "red"), point_size=4pt)))

fig = PyPlot.figure(figsize=(8, 6))
ax = fig.gca(projection="3d")
ax.set_zlim(minimum(k), maximum(k))
xgrid, ygrid = Mads.meshgrid(x, y)
ax.plot_surface(xgrid, ygrid, k, rstride=2, cstride=2, cmap=PyPlot.ColorMap("jet"), alpha=0.7, linewidth=0.25)
PyPlot.gcf()

PyPlot.clf()
PyPlot.surf(k)
PyPlot.gcf()