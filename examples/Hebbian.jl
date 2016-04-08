workspace()
ENV["JuBrain_Mode"]="MPI"
using JuBrain

model=networkModel()
model.parameters="taupre=20;taupost=20;tmax=50"
model.equations="dapre/dt=-apre/taupre;dapost/dt=-apost/taupost;dW/dt=0"

model.groups=Groups(groupName=[1,2],groupSize=[100,100])
initialize(model,groups=1,expr="tspike=(i-1)*tmax/(100-1)")
initialize(model,groups=2,expr="tspike=(100-i)*tmax/(100-1)")
Connect(model,expr="apre=0.0")
Connect(model,expr="apost=0.0")
Connect(model,expr="W=0.0")
Connect(model,pre=1,post=2,condition="i==j",expr="Apre=0.01")
Connect(model,pre=1,post=2,condition="i==j",expr="Apost=-0.01*1.05")

model.spike="abs(t-tspike).<=0.5/2"
model.plasticity="apre[j,i]+=Apre[j,i];W[j,i]+=apost[j,i];apost[i,j]+=Apost[i,j];W[i,j]+=apre[i,j]"
model.dt=0.5;model.saveVars=["W","tspike"]

model.postProcs="""
@load("Hebbian_code.jld")
using MatlabPlot
index1=model.groups[1][:localindex];index2=model.groups[2][:localindex]
index=sub2ind(size(W),index2,index1)
mplot(tspike[index2]-tspike[index1],W[index])"""

buildnet(name="Hebbian_code",model=model,duration=100)
