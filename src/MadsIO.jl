import DataStructures

"""
Load MADS input file defining a MADS problem dictionary

$(documentfunction(loadmadsfile;
argtext=Dict("filename"=>"input file name (e.g. `input_file_name.mads`)"),
keytext=Dict("julia"=>"if `true`, force using `julia` parsing functions; if `false` (default), use `python` parsing functions", 
             "format"=>"acceptable formats are `yaml` and`json`,  [default=`yaml`]")))

Usage:

- `Mads.loadmadsfile(filename)`
- `Mads.loadmadsfile(filename; julia=false)`
- `Mads.loadmadsfile(filename; julia=true)`

Returns:

- `madsdata` : Mads problem dictionary

Example:

```julia
md = loadmadsfile("input_file_name.mads")
```	
"""
function loadmadsfile(filename::String; julia::Bool=false, format::String="yaml")
	if format == "yaml"
		madsdata = loadyamlfile(filename; julia=julia) # this is not OrderedDict()
	elseif format == "json"
		madsdata = loadjsonfile(filename)
	end
	parsemadsdata!(madsdata)
	madsdata["Filename"] = filename
	if haskey(madsdata, "Observations")
		t = getobstarget(madsdata)
		isn = isnan.(t)
		if any(isn)
			l = length(isn[isn.==true])
			if l == 1
				warn("There is 1 observation with a missing target!")
			else
				warn("There are $(l) observations with missing targets!")
			end
		end
	end
	return madsdata
end

"""
Parse loaded Mads problem dictionary

$(documentfunction(parsemadsdata!;
argtext=Dict("madsdata"=>"Mads problem dictionary")))
"""
function parsemadsdata!(madsdata::Associative)
	if haskey(madsdata, "Parameters")
		parameters = DataStructures.OrderedDict()
		for dict in madsdata["Parameters"]
			for key in keys(dict)
				if !haskey(dict[key], "exp") # it is a real parameter, not an expression
					parameters[key] = dict[key]
				else
					if !haskey(madsdata, "Expressions")
						madsdata["Expressions"] = DataStructures.OrderedDict()
					end
					madsdata["Expressions"][key] = dict[key]
				end
			end
		end
		madsdata["Parameters"] = parameters
	end
	addsourceparameters!(madsdata)
	if haskey(madsdata, "Parameters")
		parameters = madsdata["Parameters"]
		for key in keys(parameters)
			if !haskey(parameters[key], "init") && !haskey(parameters[key], "exp")
				Mads.madserror("""Parameter `$key` does not have initial value; add "init" value!""")
			end
			for v in ["init", "init_max", "init_min", "max", "min", "step"]
				if haskey(parameters[key], v)
					parameters[key][v] = float(parameters[key][v])
				end
			end
			if haskey(parameters[key], "log")
				flag = parameters[key]["log"]
				if flag == "yes" || flag == true
					parameters[key]["log"] = true
					for v in ["init", "init_max", "init_min", "max", "min", "step"]
						if haskey(parameters[key], v)
							if parameters[key][v] < 0
								Mads.madserror("""The value $v for Parameter $key cannot be log-transformed; it is negative!""")
							end
						end
					end
				else
					parameters[key]["log"] = false
				end
			end
		end
	end
	checkparameterranges(madsdata)
	if haskey(madsdata, "Wells")
		wells = DataStructures.OrderedDict()
		for dict in madsdata["Wells"]
			for key in keys(dict)
				wells[key] = dict[key]
				wells[key]["on"] = true
				for i = 1:length(wells[key]["obs"])
					for k in keys(wells[key]["obs"][i])
						wells[key]["obs"][i] = wells[key]["obs"][i][k]
					end
				end
			end
		end
		madsdata["Wells"] = wells
		Mads.wells2observations!(madsdata)
	elseif haskey(madsdata, "Observations") # TODO drop zero weight observations
		observations = DataStructures.OrderedDict()
		for dict in madsdata["Observations"]
			for key in keys(dict)
				observations[key] = dict[key]
			end
		end
		madsdata["Observations"] = observations
	end
	if haskey(madsdata, "Templates")
		templates = Array{Dict}(length(madsdata["Templates"]))
		i = 1
		for dict in madsdata["Templates"]
			for key in keys(dict) # this should only iterate once
				templates[i] = dict[key]
			end
			i += 1
		end
		madsdata["Templates"] = templates
	end
	if haskey(madsdata, "Instructions")
		instructions = Array{Dict}(length(madsdata["Instructions"]))
		i = 1
		for dict in madsdata["Instructions"]
			for key in keys(dict) # this should only iterate once
				instructions[i] = dict[key]
			end
			i += 1
		end
		madsdata["Instructions"] = instructions
	end
end

"""
Save MADS problem dictionary `madsdata` in MADS input file `filename`

$(documentfunction(savemadsfile;
argtext=Dict("madsdata"=>"Mads problem dictionar",
            "parameters"=>"Dictionary with parameters (optional)",
            "filename"=>"input file name (e.g. `input_file_name.mads`)"),
keytext=Dict("julia"=>"if `true` use Julia JSON module to save, [default=`false`]",
            "explicit"=>"if `true` ignores MADS YAML file modifications and rereads the original input file, [default=`false`]")))

Usage:

- `Mads.savemadsfile(madsdata)`
- `Mads.savemadsfile(madsdata, "test.mads")`
- `Mads.savemadsfile(madsdata, parameters, "test.mads")`
- `Mads.savemadsfile(madsdata, parameters, "test.mads", explicit=true)`
"""
function savemadsfile(madsdata::Associative, filename::String=""; julia::Bool=false, explicit::Bool=false)
	if filename == ""
		filename = setnewmadsfilename(madsdata)
	end
	dumpyamlmadsfile(madsdata, filename, julia=julia)
end

function savemadsfile(madsdata::Associative, parameters::Associative, filename::String=""; julia::Bool=false, explicit::Bool=false)
	if filename == ""
		filename = setnewmadsfilename(madsdata)
	end
	if explicit
		madsdata2 = loadyamlfile(madsdata["Filename"])
		for i = 1:length(madsdata2["Parameters"])
			pdict = madsdata2["Parameters"][i]
			paramname = collect(keys(pdict))[1]
			realparam = pdict[paramname]
			if haskey(realparam, "type") && realparam["type"] == "opt"
				oldinit = realparam["init"]
				realparam["init"] = parameters[paramname]
				newinit = realparam["init"]
			end
		end
		dumpyamlfile(filename, madsdata2, julia=julia)
	else
		madsdata2 = deepcopy(madsdata)
		setparamsinit!(madsdata2, parameters)
		dumpyamlmadsfile(madsdata2, filename, julia=julia)
	end
end

"""
Save calibration results

$(documentfunction(savecalibrationresults;
argtext=Dict("madsdata"=>"",
            "results"=>"the calibration results")))
"""
function savecalibrationresults(madsdata::Associative, results)
	#TODO map estimated parameters on a new madsdata structure
	#TODO save madsdata in yaml file using dumpyamlmadsfile
	#TODO save residuals, predictions, observations (yaml?)
end

"""
Set a default MADS input file

$(documentfunction(setmadsinputfile;
argtext=Dict("filename"=>"input file name (e.g. `input_file_name.mads`)")))

Usage:

`Mads.setmadsinputfile(filename)`
"""
function setmadsinputfile(filename::String)
	global madsinputfile = filename
end

"""
Get the default MADS input file set as a MADS global variable using `setmadsinputfile(filename)`

$(documentfunction(getmadsinputfile))

Usage:

`Mads.getmadsinputfile()`

Returns:

- `filename` : input file name (e.g. `input_file_name.mads`)
"""
function getmadsinputfile()
	return madsinputfile
end

"""
Get the MADS problem root name

$(documentfunction(getmadsrootname;
argtext=Dict("madsdata"=>""),
keytext=Dict("first"=>"use the first . in filename as the seperator between root name and extention [default=`true`]",
            "version"=>"delete version information from filename for the returned rootname, [default=`false`]")))

Usage:

`madsrootname = Mads.getmadsrootname(madsdata)`

Returns:

- `r` : root of file name
"""
function getmadsrootname(madsdata::Associative; first=true, version=false)
	return getrootname(madsdata["Filename"]; first=first, version=version)
end

"""
Get directory

$(documentfunction(getdir;
argtext=Dict("filename"=>"file name")))

Returns:

- `d` : directory in file name

Example:

```julia
d = Mads.getdir("a.mads") # d = "."
d = Mads.getdir("test/a.mads") # d = "test"
```
"""
function getdir(filename::String)
	d = dirname(filename)
	if d == ""
		d = "."
	end
	return d
end

"""
Get the directory where the Mads data file is located

$(documentfunction(getmadsproblemdir;
argtext=Dict("madsdata"=>"")))

Usage:

- `Mads.getmadsproblemdir(madsdata)`

Example:

```julia
madsdata = Mads.loadmadsproblem("../../a.mads")
madsproblemdir = Mads.getmadsproblemdir(madsdata)
```

where `madsproblemdir` = `"../../"`
"""
function getmadsproblemdir(madsdata::Associative)
	getdir(madsdata["Filename"])
end

"""
Get the directory where currently Mads is running

$(documentfunction(getmadsdir))

Usage:

- `problemdir = Mads.getmadsdir()`

Returns:

- `problemdir` : problem directory
"""
function getmadsdir()
	source_path = Base.source_path()
	if typeof(source_path) == Void
		problemdir = "."
	else
		problemdir = getdir(source_path)
		madsinfo("Problem directory: $(problemdir)")
	end
	return problemdir
end

"""
Get file name root

$(documentfunction(getrootname;
argtext=Dict("filename"=>"file name"),
keytext=Dict("first"=>"use the first . in filename as the seperator between root name and extention [default=`true`]",
            "version"=>"delete version information from filename for the returned rootname, [default=`false`]")))

Returns:

- `r` : root of file name

Example:

```julia
r = Mads.getrootname("a.rnd.dat") # r = "a"
r = Mads.getrootname("a.rnd.dat", first=false) # r = "a.rnd"
```
"""
function getrootname(filename::String; first::Bool=true, version::Bool=false)
	d = splitdir(filename)
	s = split(d[2], ".")
	if !first && length(s) > 1
		r = join(s[1:end-1], ".")
	else
		r = s[1]
	end
	if version
		if ismatch(r"-v[0-9].$", r)
			rm = match(r"-v[0-9].$", r)
			r = r[1:rm.offset-1]
		elseif ismatch(r"-rerun$", r)
			rm = match(r"-rerun$", r)
			r = r[1:rm.offset-1]
		end
	end
	if length(d) > 1
		r = joinpath(d[1], r)
	end
	return r
end

"""
Set new mads file name

$(documentfunction(setnewmadsfilename;
argtext=Dict("madsdata"=>"",
            "filename"=>"file name")))

Returns:

- the new file name 
"""
function setnewmadsfilename(madsdata::Associative)
	setnewmadsfilename(madsdata["Filename"])
end
function setnewmadsfilename(filename::String)
	dir = getdir(filename)
	root = splitdir(getrootname(filename))[end]
	if ismatch(r"-v[0-9].$", root)
		rm = match(r"-v([0-9]).$", root)
		l = rm.captures[1]
		s = split(rm.match, "v")
		v = parse(Int, s[2]) + 1
		l = length(s[2])
		f = "%0" * string(l) * "d"
		filename = "$(root[1:rm.offset-1])-v$(sprintf(f, v)).mads"
	else
		filename = "$(root)-rerun.mads"
	end
	return joinpath(dir, filename)
end

"""
Get next mads file name

$(documentfunction(getnextmadsfilename;
argtext=Dict("filename"=>"file name")))

Returns:

- `filename` : next mads file name
"""
function getnextmadsfilename(filename::String)
	t0 = 0
	filename_old = filename
	while isfile(filename)
		t = mtime(filename)
		if t < t0
			filename = filename_old
			break
		else
			t0 = t
			filename_old = filename
			filename = setnewmadsfilename(filename_old)
			if !isfile(filename)
				filename = filename_old
				break
			end
		end
	end
	return filename
end

"""
Get file name extension

$(documentfunction(getextension;
argtext=Dict("filename"=>"file name")))

Returns:

- file name extension

Example:

```julia
ext = Mads.getextension("a.mads") # ext = "mads"
```
"""
function getextension(filename::String)
	d = splitdir(filename)
	s = split(d[2], ".")
	if length(s) > 1
		return s[end]
	else
		return ""
	end
end

"""
Check the directories where model outputs should be saved for MADS

$(documentfunction(checkmodeloutputdirs;
argtext=Dict("madsdata"=>"")))

Returns:

- true or false
"""
function checkmodeloutputdirs(madsdata::Associative)
	directories = Array{String}(0)
	if haskey(madsdata, "Instructions") # Templates/Instructions
		for instruction in madsdata["Instructions"]
			filename = instruction["read"]
			push!(directories, getdir(filename))
		end
	end
	if haskey(madsdata, "JLDPredictions") # JLD
		for filename in vcat(madsdata["JLDPredictions"])
			push!(directories, getdir(filename))
		end
	end
	if haskey(madsdata, "JSONPredictions") # JSON
		for filename in vcat(madsdata["JSONPredictions"])
			push!(directories, getdir(filename))
		end
	end
	if haskey(madsdata, "YAMLPredictions") # YAML
		for filename in vcat(madsdata["YAMLPredictions"])
			push!(directories, getdir(filename))
		end
	end
	if haskey(madsdata, "ASCIIPredictions") # ASCII
		for filename in vcat(madsdata["ASCIIPredictions"])
			push!(directories, getdir(filename))
		end
	end
	d = unique(directories)
	nd = length(directories)
	if nd == 0
		return true
	elseif nd == 1 && d[1] == "."
		return true
	else
		return false
	end
end

"""
Set model input files; delete files where model output should be saved for MADS

$(documentfunction(setmodelinputs;
argtext=Dict("madsdata"=>"",
            "parameters"=>""),
keytext=Dict("path"=>"path for the files, [default=`.`]")))
"""
function setmodelinputs(madsdata::Associative, parameters::Associative; path::String=".")
	if haskey(madsdata, "Instructions") # Templates/Instructions
		for instruction in madsdata["Instructions"]
			filename = instruction["read"]
			Mads.rmfile(filename, path=path) # delete the parameter file links
		end
	end
	if haskey(madsdata, "Templates") # Templates/Instructions
		for template in madsdata["Templates"]
			filename = template["write"]
			Mads.rmfile(filename, path=path) # delete the parameter file links
		end
		writeparameters(madsdata, parameters)
	end
	#TODO move the writing into the "writeparameters" function
	if haskey(madsdata, "JLDParameters") # JLD
		for filename in vcat(madsdata["JLDParameters"])
			Mads.rmfile(filename, path=path) # delete the parameter file links
		end
		JLD.save("$(madsdata["JLDParameters"])", parameters) # create parameter files
	end
	if haskey(madsdata, "JLDPredictions") # JLD
		for filename in vcat(madsdata["JLDPredictions"])
			Mads.rmfile(filename, path=path) # delete the parameter file links
		end
	end
	if haskey(madsdata, "JSONParameters") # JSON
		for filename in vcat(madsdata["JSONParameters"])
			Mads.rmfile(filename, path=path) # delete the parameter file links
		end
		dumpjsonfile(madsdata["JSONParameters"], parameters) # create parameter files
	end
	if haskey(madsdata, "JSONPredictions") # JSON
		for filename in vcat(madsdata["JSONPredictions"])
			Mads.rmfile(filename, path=path) # delete the parameter file links
		end
	end
	if haskey(madsdata, "YAMLParameters") # YAML
		for filename in vcat(madsdata["YAMLParameters"])
			Mads.rmfile(filename, path=path) # delete the parameter file links
		end
		dumpyamlfile(joinpath(path, madsdata["YAMLParameters"]), parameters) # create parameter files
	end
	if haskey(madsdata, "YAMLPredictions") # YAML
		for filename in vcat(madsdata["YAMLPredictions"])
			Mads.rmfile(filename, path=path) # delete the parameter file links
		end
	end
	if haskey(madsdata, "ASCIIParameters") # ASCII
		filename = madsdata["ASCIIParameters"]
		Mads.rmfile(filename, path=path) # delete the parameter file links
		#TODO this does NOT work; `parameters` are not required to be Ordered Dictionary
		dumpasciifile(joinpath(path, madsdata["ASCIIParameters"]), values(parameters)) # create an ASCII parameter file
	end
	if haskey(madsdata, "ASCIIPredictions") # ASCII
		for filename in vcat(madsdata["ASCIIPredictions"])
			Mads.rmfile(filename, path=path) # delete the parameter file links
		end
	end
end

"""
Read model outputs saved for MADS

$(documentfunction(readmodeloutput;
argtext=Dict("madsdata"=>""),
keytext=Dict("obskeys"=>"[default=getobskeys(madsdata)]")))
"""
function readmodeloutput(madsdata::Associative; obskeys::Vector=getobskeys(madsdata))
	results = DataStructures.OrderedDict()
	if haskey(madsdata, "Instructions") # Templates/Instructions
		results = readobservations(madsdata, obskeys)
	end
	if haskey(madsdata, "JLDPredictions") # JLD
		for filename in vcat(madsdata["JLDPredictions"])
			results = merge(results, JLD.load(filename))
		end
	end
	if haskey(madsdata, "JSONPredictions") # JSON
		for filename in vcat(madsdata["JSONPredictions"])
			results = merge(results, loadjsonfile(filename))
		end
	end
	if haskey(madsdata, "YAMLPredictions") # YAML
		for filename in vcat(madsdata["YAMLPredictions"])
			results = merge(results, loadyamlfile(filename))
		end
	end
	if haskey(madsdata, "ASCIIPredictions") # ASCII
		predictions = loadasciifile(madsdata["ASCIIPredictions"])
		obsid=[convert(String,k) for k in obskeys]
		@assert length(obskeys) == length(predictions)
		results = merge(results, DataStructures.OrderedDict{String, Float64}(zip(obsid, predictions)))
	end
	return convert(DataStructures.OrderedDict{Any,Float64}, results)
end

"""
Get files in the current directory or in a directory defined by `path` matching pattern `key` which can be a string or regular expression

$(documentfunction(searchdir;
argtext=Dict("key"=>"matching pattern for Mads input files (string or regular expression accepted)"),
keytext=Dict("path"=>"search directory for the mads input files, [default=`.`]")))

Returns:

- `filename` : an array with file names matching the pattern in the specified directory

Examples:

```julia
- `Mads.searchdir("a")`
- `Mads.searchdir(r"[A-B]"; path = ".")`
- `Mads.searchdir(r".*\.cov"; path = ".")`
```
"""
searchdir(key::Regex; path::String = ".") = filter(x->ismatch(key, x), readdir(path))
searchdir(key::String; path::String = ".") = filter(x->contains(x, key), readdir(path))

"""
Filter dictionary keys based on a string or regular expression

$(documentfunction(filterkeys;
argtext=Dict("dict"=>"dictionary",
            "key"=>"the regular expression or string used to filter dictionary keys")))
"""
filterkeys(dict::Associative, key::Regex) = key == r"" ? collect(keys(dict)) : filter(x->ismatch(key, x), collect(keys(dict)))
filterkeys(dict::Associative, key::String = "") = key == "" ? collect(keys(dict)) : filter(x->contains(x, key), collect(keys(dict)))

"""
Find indexes for dictionary keys based on a string or regular expression

$(documentfunction(indexkeys;
argtext=Dict("dict"=>"dictionary",
            "key"=>"the key to find index for")))
"""
indexkeys(dict::Associative, key::Regex) = key == r"" ? find(collect(keys(dict))) : find(x->ismatch(key, x), collect(keys(dict)))
indexkeys(dict::Associative, key::String = "") = key == "" ? find(collect(keys(dict))) : find(x->contains(x, key), collect(keys(dict)))

getdictvalues(dict::Associative, key::Regex) = map(y->(y, dict[y]), filterkeys(dict, key))
getdictvalues(dict::Associative, key::String = "") = map(y->(y, dict[y]), filterkeys(dict, key))

@doc """
Get dictionary values for keys based on a string or regular expression

$(documentfunction(getdictvalues;
argtext=Dict("dict"=>"dictionary",
             "key"=>"the key to find value for")))
""" getdictvalues

"""
Write `parameters` via MADS template (`templatefilename`) to an output file (`outputfilename`)

$(documentfunction(writeparametersviatemplate;
argtext=Dict("parameters"=>"parameters",
            "templatefilename"=>"tmplate file name",
            "outputfilename"=>"output file name"),
keytext=Dict("respect_space"=>"[default=`false`]")))
"""
function writeparametersviatemplate(parameters, templatefilename, outputfilename; respect_space::Bool=false)
	tplfile = open(templatefilename) # open template file
	line = readline(tplfile) # read the first line that says "template $separator\n"
	if length(line) >= 10 && line[1:9] == "template "
		separator = line[10] # template separator
		lines = readlines(tplfile)
	else
		#it doesn't specify the separator -- assume it is '#'
		separator = '#'
		lines = [line; readlines(tplfile)]
	end
	close(tplfile)
	outfile = open(outputfilename, "w")
	for line in lines
		splitline = split(line, separator) # two separators are needed for each parameter
		if rem(length(splitline), 2) != 1
			error("The number of separators (\"$separator\") is not even in template file $templatefilename on line:\n$line")
		end
		for i = 1:div(length(splitline)-1, 2)
			write(outfile, splitline[2 * i - 1]) # write the text before the parameter separator
			varname = strip(splitline[2 * i])
			if respect_space
				l = length(splitline[2 * i])
				s = Mads.sprintf("%.$(l)g", parameters[varname])
			else
				s = string(parameters[varname])
			end
			write(outfile, s)
			madsinfo("Replacing " * varname * " -> " * s, 1)
		end
		write(outfile, splitline[end]) # write the rest of the line after the last separator
	end
	close(outfile)
end
function writeparameters(madsdata::Associative)
	paramsinit = getparamsinit(madsdata)
	paramkeys = getparamkeys(madsdata)
	writeparameters(madsdata, Dict(zip(paramkeys, paramsinit)); respect_space=false)
end
function writeparameters(madsdata::Associative, parameters::Associative; respect_space=false)
	expressions = evaluatemadsexpressions(madsdata, parameters)
	paramsandexps = merge(parameters, expressions)
	respect_space = Mads.haskeyword(madsdata, "respect_space")
	for template in madsdata["Templates"]
		writeparametersviatemplate(paramsandexps, template["tpl"], template["write"]; respect_space=respect_space)
	end
end

"""
Convert an instruction line in the Mads instruction file into regular expressions

$(documentfunction(instline2regexs;
argtext=Dict("instline"=>"instruction line")))

Returns:

- `regexs` : regular expressions
- `obsnames` : 
- `getparamhere` :
"""
function instline2regexs(instline::String)
	floatregex = r"\h*[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?"
	regex = r"@[^@]*@|w|![^!]*!"
	offset = 1
	regexs = Regex[]
	obsnames = String[]
	getparamhere = Bool[]
	while offset <= length(instline) && ismatch(regex, instline, offset - 1)#this may be a julia bug -- offset for ismatch and match seem to be based on zero vs. one indexing
		m = match(regex, instline, offset)
		if m == nothing
			Mads.madserror("match not found for instruction line:\n$instline\nnear \"$(instline[offset:end])\"")
		end
		offset = m.offset + length(m.match)
		if m.match[1] == '@'
			if isspace(m.match[end - 1])
				push!(regexs, Regex(string("\\h*", m.match[2:end - 1])))
			else
				push!(regexs, Regex(string("\\h*", m.match[2:end - 1], "[^\\s]*")))
			end
			push!(getparamhere, false)
		elseif m.match[1] == '!'
			push!(regexs, floatregex)
			if m.match[2:end - 1] != "dum"
				push!(obsnames, m.match[2:end - 1])
				push!(getparamhere, true)
			else
				push!(getparamhere, false)
			end
		elseif m.match == "w"
			push!(regexs, r"\h+")
			push!(getparamhere, false)
		else
			Mads.madserror("Unknown instruction file instruction: $(m.match)")
		end
	end
	return regexs, obsnames, getparamhere
end

"""
Match an instruction line in the Mads instruction file with model input file

$(documentfunction(obslineismatch;
argtext=Dict("obsline"=>"instruction line",
            "regexs"=>"")))

Returns:

- true or false
"""
function obslineismatch(obsline::String, regexs::Array{Regex, 1})
	bigregex = Regex(string(map(x->x.pattern, regexs)...))
	return ismatch(bigregex, obsline)
end

"""
Get observations for a set of regular expressions

$(documentfunction(regexs2obs;
argtext=Dict("obsline"=>"",
            "regexs"=>"regular expressions",
            "obsnames"=>"",
            "getparamhere"=>"")))

Returns:

- `obsdict` : observations
"""
function regexs2obs(obsline::String, regexs::Array{Regex, 1}, obsnames::Array{String, 1}, getparamhere::Array{Bool, 1})
	offset = 1
	obsnameindex = 1
	obsdict = Dict{String, Float64}()
	for i = 1:length(regexs)
		m = match(regexs[i], obsline, offset)
		if m == nothing
			Mads.madserror("match not found for $(regexs[i]) in observation line: $(strip(obsline)) (\"$(strip(obsline[offset:end]))\")")
		else
			if getparamhere[i]
				obsdict[obsnames[obsnameindex]] = parse(Float64, m.match)
				obsnameindex += 1
			end
		end
		offset = m.offset + length(m.match)
	end
	return obsdict
end

"""
Apply Mads instruction file `instructionfilename` to read model input file `inputfilename`

$(documentfunction(ins_obs;
argtext=Dict("instructionfilename"=>"instruction file name",
            "inputfilename"=>"read model input file")))

Returns:

- `obsdict` : result dictionary
"""
function ins_obs(instructionfilename::String, inputfilename::String)
	instfile = open(instructionfilename, "r")
	obsfile = open(inputfilename, "r")
	obslineitr = eachline(obsfile)
	state = start(obslineitr)
	obsdict = Dict{String, Float64}()
	for instline in eachline(instfile)
		regexs, obsnames, getparamhere = instline2regexs(instline)
		gotmatch = false
		while !gotmatch && !done(obslineitr, state)
			obsline, state = next(obslineitr, state)
			if obslineismatch(obsline, regexs)
				merge!(obsdict, regexs2obs(obsline, regexs, obsnames, getparamhere))
				gotmatch = true
			end
		end
		if !gotmatch
			Mads.madserror("Did not get a match for instruction file ($instructionfilename) line:\n$instline")
		end
	end
	close(instfile)
	close(obsfile)
	return obsdict
end

"""
Read observations

$(documentfunction(readobservations;
argtext=Dict("madsdata"=>"",
            "obskeys"=>"observation keys, [default=`getobskeys(madsdata)`]")))

Returns:

- `observations` : observations
"""
function readobservations(madsdata::Associative, obskeys::Vector=getobskeys(madsdata))
	observations = Dict()
	obscount = Dict(zip(obskeys, zeros(Int, length(obskeys))))
	for instruction in madsdata["Instructions"]
		obs = ins_obs(instruction["ins"], instruction["read"])
		for k in keys(obs)
			obscount[k] += 1
			observations[k] = obscount[k] > 1 ? observations[k] + obs[k] : obs[k]
		end
	end
	missing = 0
	c = 0
	for k in keys(obscount)
		c += 1
		if obscount[k] == 0
			missing += 1
			madsinfo("Observation $k is missing!", 1)
		elseif obscount[k] > 1
			observations[k] /= obscount[k]
			madsinfo("Observation $k detected $(obscount[k]) times; an average is computed")
		end
	end
	if missing > 0
		madswarn("Observations (total count = $(missing)) are missing!")
	end
	return observations
end

"""
Dump well data from MADS problem dictionary into a ASCII file

$(documentfunction(dumpwelldata;
argtext=Dict("madsdata"=>"well data",
            "filename"=>"output file name")))

Dumps:

- `filename` : a ASCII file 
"""
function dumpwelldata(madsdata::Associative, filename::String)
	if haskey(madsdata, "Wells")
		outfile = open(filename, "w")
		write(outfile, "well_name, x_coord [m], x_coord [m], z_coord [m], time [years], concentration [ppb]\n")
		for n in keys(madsdata["Wells"])
			x = madsdata["Wells"]["$n"]["x"]
			y = madsdata["Wells"]["$n"]["y"]
			z0 = madsdata["Wells"]["$n"]["z0"]
			z1 = madsdata["Wells"]["$n"]["z1"]
			o = madsdata["Wells"]["$n"]["obs"]
			for i in 1:length(o)
				c = o[i]["c"]
				t = o[i]["t"]
				write(outfile, "$n, $x, $y, $z0, $t, $c\n")
			end
		end
		close(outfile)
	end
end

"""
Create a symbolic link of all the files in a directory `dirsource` in a directory `dirtarget`

$(documentfunction(symlinkdirfiles;
argtext=Dict("dirsource"=>"source directory",
            "dirtarget"=>"target directory")))
"""
function symlinkdirfiles(dirsource::String, dirtarget::String)
	for f in readdir(dirsource)
		if !isdir(f)
			symlinkdir(f, dirtarget)
		else
			Base.mkdir(joinpath(dirtarget, f))
			symlinkdirfiles(f, joinpath(dirtarget, f))
		end
	end
end

"""
Create a symbolic link of a file `filename` in a directory `dirtarget`

$(documentfunction(symlinkdir;
argtext=Dict("filename"=>"file name",
            "dirtarget"=>"target directory")))
"""
function symlinkdir(filename::String, dirtarget::String)
	filenametarget = joinpath(dirtarget, filename)
	if !islink(filenametarget) && !isdir(filenametarget) && !isfile(filenametarget)
		symlink(abspath(filename), filenametarget)
	end
end

"""
Remove directory

$(documentfunction(rmdir;
argtext=Dict("dir"=>"the directory to be removed"),
keytext=Dict("path"=>"path of the directory, [default=`current path`]")))
"""
function rmdir(dir::String; path::String="")
	if path != "" && path != "."
		dir = joinpath(path, dir)
	end
	if isdir(dir)
		rm(dir, recursive=true)
	end
end

"""
Remove file

$(documentfunction(rmfile;
argtext=Dict("filename"=>"the file to be removed"),
keytext=Dict("path"=>"path of the file, [default=`current path`]")))
"""
function rmfile(filename::String; path::String="")
	if path != "" && path != "."
		filename = joinpath(path, filename)
	end
	if isfile(filename)
		rm(filename)
	end
end

"""
Remove files with extension `ext`

$(documentfunction(rmfiles_ext;
argtext=Dict("ext"=>"extension"),
keytext=Dict("path"=>"path of the files to be removed, [default=`.`]")))
"""
function rmfiles_ext(ext::String; path::String=".")
	for f in searchdir(Regex(string(".*\\.", ext)); path=path)
		rm(joinpath(path, f))
	end
end

"""
Remove files with root `root`

$(documentfunction(rmfiles_root;
argtext=Dict("root"=>"root"),
keytext=Dict("path"=>"path of the files to be removed, [default=`.`]")))
"""
function rmfiles_root(root::String; path::String=".")
	s = splitdir(root)
	if s[1] != ""
		path = s[1]
		root = s[2]
	end
	for f in searchdir(Regex(string(root, "\\..*")); path=path)
		rm(joinpath(path, f))
	end
end

"""
Create temporary directory

$(documentfunction(createtempdir;
argtext=Dict("tempdirname"=>"tmporary directory name")))
"""
function createtempdir(tempdirname::String)
	attempt = 0
	trying = true
	while trying
		try
			attempt += 1
			Mads.mkdir(tempdirname)
			Mads.madsinfo("Created temporary directory: $(tempdirname)", 1)
			trying = false
		catch errmsg
			sleep(attempt * 0.5)
			if attempt > 3
				printerrormsg(errmsg)
				madscritical("$(e)\nTemporary directory $(tempdirname) cannot be created!")
				trying = false
			end
		end
	end
end

"""
Link files in a temporary directory

$(documentfunction(linktempdir;
argtext=Dict("madsproblemdir"=>"mads problem directory",
            "tempdirname"=>"temporary directory name")))
"""
function linktempdir(madsproblemdir::String, tempdirname::String)
	attempt = 0
	trying = true
	while trying
		try
			attempt += 1
			Mads.symlinkdirfiles(madsproblemdir, tempdirname)
			Mads.madsinfo("Links created in temporary directory: $(tempdirname)", 1)
			trying = false
		catch errmsg
			Mads.rmdir(tempdirname)
			sleep(attempt * 1)
			Mads.createtempdir(tempdirname)
			if attempt > 4
				pprinterrormsg(errmsg)
				madscritical("$(e)\nLinks cannot be created in temporary directory $(tempdirname) cannot be created!")
				trying = false
			end
		end
	end
end

function mkdir(dirname::String)
	if !isdir(dirname)
		Base.mkdir(dirname)
	end
end
