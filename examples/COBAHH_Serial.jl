using JuBrain
model=NetworkModel()

model.parameters="""
area = 20000*um^2;Cm = 1*ufarad*cm^(-2)*area;gl = 5e-5*siemens*cm^(-2)*area
El = -65*mV;EK = -90*mV;ENa = 50*mV;VT = -63*mV
g_na = 100*msiemens*cm^(-2)*area;g_kd = 30*msiemens*cm^(-2)*area
taue = 5*ms;taui = 10*ms;Ee = 0*mV;Ei = -80*mV"""
model.equations="""
dv/dt=(gl*(El-v)+ge*(Ee-v)+gi*(Ei-v)-g_na*m^3*h*(v-ENa)-g_kd*n^4*(v-EK))/Cm
dm/dt=0.32*(13-v+VT)/(exp((13-v+VT)/4)-1)*(1-m)-0.28*(v-VT-40)/(exp((v-VT-40)/5)-1)*m
dn/dt=0.032*(15-v+VT)/(exp((15-v+VT)/5)-1)*(1-n)-0.5*exp((10-v+VT)/40)*n
dh/dt=0.128*exp((17-v+VT)/18)*(1-h)-4/(1+exp((40-v+VT)/5))*h
dge/dt=-ge/taue;dgi/dt=-gi/taui"""

model.groups=makeGroups(groupName=["e","i"],groupSize=[3200,800])
initialize(model,groups="all",expr="v=El+5*(randn()-1)")
initialize(model,groups="all",expr="h=1.0")
initialize(model,groups="all",expr="ge=(randn()*1.5+4)*10*nS")
initialize(model,groups="all",expr="gi=(randn()*12+20)*10*nS")
spConnect(model,pre="e",post="all",expr="we=6*nS",p=0.02)
spConnect(model,pre="i",post="all",expr="wi=67*nS",p=0.02)

model.spike="v.>-20;t.>ts+3"
model.synapse="ge+=we;gi+=wi"
model.record=[1,10,100]

model.dt=0.06;model.solver="Euler4"
buildNetwork(name="temp",model=model,duration=100)
@load("temp.jld")
using MatlabPlot
figure();mplot(vRecord')
