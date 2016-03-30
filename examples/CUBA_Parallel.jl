using JuBrain
model=NetworkModel()

model.parameters="""
τᵥ = 20*ms;  τₑ = 5*ms;   τᵢ = 10*ms
Vt = -50*mV; Vᵣ = -60*mV; El = -49*mV"""
model.equations="dv/dt=(gₑ+gᵢ-(v-El))/τᵥ;dgₑ/dt=-gₑ/τₑ;dgᵢ/dt=-gᵢ/τᵢ"
model.spike="v.>Vt"
model.reset="v=Vᵣ"
model.synapse="gₑ+=wₑ;gᵢ+=wᵢ"""

model.groups=makeGroups(groupName=["e","i"],groupSize=[3200,800])
initialize(model,groups="all",expr="v=Vᵣ+rand()*(Vt-Vᵣ)",parallel=true)
spConnect(model,pre="e",post="all",expr="wₑ=(60*0.27/10)*mV",p=0.02)
spConnect(model,pre="i",post="all",expr="wᵢ=(-20*4.5/10)*mV",p=0.02)

model.nCores=3;model.synctime=1.0;
buildNetwork(name="temp",model=model,duration=1000)
@load("temp.jld")
using MatlabPlot
figure();mplot(tSpike,spikeNeuron,".k")
