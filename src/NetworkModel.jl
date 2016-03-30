export NetworkModel

type NetworkModel
  dt::Float64
  groups::Dict
  parameters::AbstractString
  equations::AbstractString
  initialization::AbstractString
  connection::AbstractString
  spike::AbstractString
  reset::AbstractString
  synapse::AbstractString
  plasticity::AbstractString
  record::Array
  nCores::Int64
  solver::AbstractString
  synctime::Float64
  saveVars::Array
  NetworkModel()=new(0.1,Dict(),"","","","","","","","",[],0,"Euler1",0.0,[])
end 