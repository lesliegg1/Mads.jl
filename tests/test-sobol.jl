using DataStructures
function madsmodelrun(parameters::Dict) # Sobol Test
	f = 1
	i = 1
	for d in collect(keys(parameters))
		a = ( i > 2 ) ? 3 : 0
		b = ( abs( 4.0 * ( parameters[d] + 0.5 ) - 2 ) + a ) / ( 1 + a );
		f = f * b
		i = i + 1
	end
	#predictions = {"o1"=>f}
	predictions = OrderedDict{String, Float64}(zip(["o1"], [f]))
	return predictions
end
