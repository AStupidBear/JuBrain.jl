workspace()
ENV["JuBrain_Mode"]="MPI"
using JuBrain
model=networkModel()

model.parameters="""
τᵥ = 20*ms;  τₑ = 5*ms;   τᵢ = 10*ms
Vt = -50*mV; Vᵣ = -60*mV; El = -49*mV"""
model.equations="dv/dt=(gₑ+gᵢ-(v-El))/τᵥ;dgₑ/dt=-gₑ/τₑ;dgᵢ/dt=-gᵢ/τᵢ"
model.spike="v.>Vt"
model.reset="v=Vᵣ"
model.synapse="gₑ+=wₑ;gᵢ+=wᵢ"""
N=4000;Ne=N÷5*4;Ni=N÷5;
model.groups=Groups(groupName=["e","i"],groupSize=[Ne,Ni])
initialize(model,groups=["e","i"],expr="v=Vᵣ+rand()*(Vt-Vᵣ)")
spConnect(model,pre="e",post=["e","i"],expr="wₑ=(60*0.27/10)*mV",p=0.02)
spConnect(model,pre="i",post=["e","i"],expr="wᵢ=(-20*4.5/10)*mV",p=0.02)

model.postProcs="""
@load("CUBA_code.jld")
using MatlabPlot;figure();mplot(tSpike,spikeNeuron,".k")"""

model.nCores=4;model.synctime=1.0;
buildnet(name="CUBA_code",model=model,duration=1000)
