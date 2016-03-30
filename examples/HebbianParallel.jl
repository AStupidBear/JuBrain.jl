using JuBrain

model=NetworkModel()
model.parameters="taupre=20;taupost=20;tmax=50"
model.equations="dapre/dt=-apre/taupre;dapost/dt=-apost/taupost;dw/dt=0"

model.groups=makeGroups(groupName=[1,2],groupSize=[100,100])
initialize(model,groups=1,expr="tspike=(i-1)*tmax/(100-1)")
initialize(model,groups=2,expr="tspike=(100-i)*tmax/(100-1)")
Connect(model,expr="apre=0.0",parallel=true)
Connect(model,expr="apost=0.0",parallel=true)
Connect(model,expr="w=0.0",parallel=true)
Connect(model,pre=1,post=2,condition="i==j",expr="Apre=0.01")
Connect(model,pre=1,post=2,condition="i==j",expr="Apost=-0.01*1.05")

model.spike="t≂tspike"
model.plasticity="apre[j,i]+=Apre[j,i];w[j,i]+=apost[j,i];apost[i,j]+=Apost[i,j];w[i,j]+=apre[i,j]"
model.dt=0.5;model.saveVars=["w","tspike"];model.nCores=3;

buildNetwork(name="temp",model=model,duration=100)
@load("temp.jld")
using MatlabPlot
groups=model.groups
index=sub2ind(size(w),model.groups[2],model.groups[1])
mplot(tspike[groups[2]]-tspike[groups[1]],w[index])
