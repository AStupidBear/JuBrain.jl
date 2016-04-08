module JuBrain

using JLD

if !haskey(ENV,"JuBrain_Mode")
	ENV["JuBrain_Mode"]="SingleCore"
end

if ENV["JuBrain_Mode"]=="SingleCore"
	include("SingleCore/utils.jl")
	include("SingleCore/networkModel.jl")
	include("SingleCore/Groups.jl")
	include("SingleCore/initialize.jl")
	include("SingleCore/Connect.jl")
	include("SingleCore/spConnect.jl")
	include("SingleCore/buildnet.jl")
elseif ENV["JuBrain_Mode"]=="OpenMP"
	include("OpenMP/utils.jl")
	include("OpenMP/networkModel.jl")
	include("OpenMP/Groups.jl")
	include("OpenMP/initialize.jl")
	include("OpenMP/Connect.jl")
	include("OpenMP/spConnect.jl")
	include("OpenMP/buildnet.jl")
elseif 	ENV["JuBrain_Mode"]=="MPI"
	include("MPI/utils.jl")
	include("MPI/networkModel.jl")
	include("MPI/Groups.jl")
	include("MPI/initialize.jl")
	include("MPI/Connect.jl")
	include("MPI/spConnect.jl")
	include("MPI/buildnet.jl")
end

end # module
