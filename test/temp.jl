using JLD

if 0<=1 && nprocs()>1
  rmprocs(workers())
end
if 0>1 && (addCores=0-nworkers())>0
  addprocs(addCores)
end

@everywhere begin
metre=1e2;meter=1e2;cm=metre/1e2;mm=metre/1e3;um=metre/1e6;nm=metre/1e9;
second=1e3;ms=second/1e3;
Hz=1/second;
voltage=1e3;mV=voltage/1e3;
ampere=1e6;mA=ampere/1e3;uA=ampere/1e6;nA=ampere/1e9;
farad=1e6;uF=ufarad=farad/1e6;
siemens=1e3;mS=msiemens=siemens/1e3;nS=nsiemens=siemens/1e9
end

@everywhere begin
τᵥ = 20*ms;  τₑ = 5*ms;   τᵢ = 10*ms
Vt = -50*mV; Vᵣ = -60*mV; El = -49*mV
end

# function
@everywhere Fv(v::Array{Float64},gₑ::Array{Float64},gᵢ::Array{Float64},t::Float64)=(gₑ+gᵢ-(v-El))./τᵥ
@everywhere Fgₑ(v::Array{Float64},gₑ::Array{Float64},gᵢ::Array{Float64},t::Float64)=-gₑ./τₑ
@everywhere Fgᵢ(v::Array{Float64},gₑ::Array{Float64},gᵢ::Array{Float64},t::Float64)=-gᵢ./τᵢ

function temp(iteration::Int64=10)

t=0.0
dt=0.1
N=4000
syncIter=1

# initialize variables
v=zeros(N)
gₑ=zeros(N)
gᵢ=zeros(N)
v=zeros(N)
for i=1:N v[i]=Vᵣ+rand()*(Vt-Vᵣ) end


# initialize connections
wₑ=spzeros(N,N)
wₑ[1:N,1:3200]=(60*0.27/10)*mV*sprand(N,3200,0.02)
wᵢ=spzeros(N,N)
wᵢ[1:N,3201:4000]=(-20*4.5/10)*mV*sprand(N,800,0.02)


# initialize tSpike
tSpike=zeros(round(Int64,N*iteration*dt))
ts=zeros(N)
spikeNeuron=zeros(Int64,round(Int64,N*iteration*dt))
state=1

# print status
if iteration>=50
    println("simulation starts...")
else
  println("compiling...")
end

tic()
@fastmath @inbounds for k=1:iteration

# report
if k%(1000÷syncIter)==0
   @printf("%s%4.2f finished","%",100*k/iteration)
end

# integrate
for idx=1:syncIter
Δv=dt*Fv(v,gₑ,gᵢ,t)
Δgₑ=dt*Fgₑ(v,gₑ,gᵢ,t)
Δgᵢ=dt*Fgᵢ(v,gₑ,gᵢ,t)
v+=Δv
gₑ+=Δgₑ
gᵢ+=Δgᵢ

end

# spike
isExceedThreshold=v.>Vt
isSpike=isExceedThreshold
spikeIndex=find(isSpike)
nSpike=length(spikeIndex)
tSpike[state:state+nSpike-1]=t
ts[spikeIndex]=t
spikeNeuron[state:state+nSpike-1]=spikeIndex
state+=nSpike

# reset
v[spikeIndex]=Vᵣ

# synapse
gₑ+=sum(wₑ[:,spikeIndex],2)
gᵢ+=sum(wᵢ[:,spikeIndex],2)



t+=syncIter*dt
end # end of for loop 
toc()

# save variables
try jldopen("temp.jld","w") do fid
  try  write(fid,"spikeNeuron",spikeNeuron[1:state-1])  end
  try  write(fid,"tSpike",tSpike[1:state-1])            end
  try  write(fid,"vRecord",vRecord)   end
  end #end of do
end #end of try jldopen

end # end of function

# precompile and run
precompile(temp,(10000,))
temp(20)
temp(20)
temp(10000)
