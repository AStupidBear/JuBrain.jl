export buildNetwork

function buildNetwork(;name="temp",model=NetworkModel(),method="Euler1",duration=0.1)
  iteration=round(Int64,duration/model.dt)
  syncIter=model.synctime>0?round(Int64,model.synctime÷model.dt):1
  iteration=iteration÷syncIter

  # open a file
  fid=open(name*".jl","w")
  # add core
  str="""
  using JLD

  if $(model.nCores)<=1 && nprocs()>1
    rmprocs(workers())
  end
  if $(model.nCores)>1 && (addCores=$(model.nCores)-nworkers())>0
    addprocs(addCores)
  end
  """
  println(fid,str)

  # units
  unit="""
  metre=1e2;meter=1e2;cm=metre/1e2;mm=metre/1e3;um=metre/1e6;nm=metre/1e9;
  second=1e3;ms=second/1e3;
  Hz=1/second;
  voltage=1e3;mV=voltage/1e3;
  ampere=1e6;mA=ampere/1e3;uA=ampere/1e6;nA=ampere/1e9;
  farad=1e6;uF=ufarad=farad/1e6;
  siemens=1e3;mS=msiemens=siemens/1e3;nS=nsiemens=siemens/1e9"""
  println(fid,"@everywhere begin\n",unit,"\nend\n")

  # parameters
  println(fid,"@everywhere begin\n",model.parameters,"\nend\n")

  # equations
  eqs=map(strip,split(replace(model.equations,";","\n"),"\n"));
  vars=[]
  diffEqs=[]

  for k=1:length(eqs)
    if eqs[k][1]=='d'
      vars=[vars;match(r"(?<=d).*(?=/dt)",eqs[k]).match]
      diffEq=vectorize(match(r"(?<==).*$",eqs[k]).match)
      diffEqs=[diffEqs;diffEq]
    else
      funcName=match(r"^.*(?==)",eqs[k]).match
      funcExpr=vectorize(match(r"(?<==).*$",eqs[k]).match)
      diffEqs=map(diffEq->replace(diffEq,funcName,funcExpr),diffEqs)
    end
  end

  varsType=map(var->var*"::Array{Float64}",vars)
  argumentType=join([varsType;"t::Float64"],",");
  println(fid,"# function")
  for k=1:length(vars)
    println(fid,"@everywhere ""F",vars[k],"(",argumentType,")=",diffEqs[k])
  end
  println(fid)


  # function
  println(fid,"function $name(iteration::Int64=10)\n")
  println(fid,"t=0.0")
  println(fid,"dt=",model.dt)
  println(fid,"N=",model.groups[:N])
  println(fid,"syncIter=",syncIter,"\n")

  # initialize variables
  println(fid,"# initialize variables")
  if model.nCores>0
    for var in vars
      println(fid,var,"=SharedArray(Float64,N)")
    end
  elseif model.nCores==0
    for var in vars
      println(fid,var,"=zeros(N)")
    end
  end
  println(fid,model.initialization,"\n")

  # connection
  println(fid,"# initialize connections\n",model.connection,"\n")

  # report
  report="""# report
  if k%(1000÷syncIter)==0
     @printf("%s%4.2f finished","%",100*k/iteration)
  end
  """

  # integrate

  if model.nCores>0
    argument=join([map(var->var*"[localindex]",vars);"t"],",")
  else
    argument=join([vars;"t"],",")
  end
  splitArg=split(argument,",")
  argumentTemp=join([splitArg[1]*"+Δ$(vars[1])";splitArg[2:end]],",")

  func=map(var->"F$var($argument)",vars)
  tempFunc="F$(vars[1])($argumentTemp)"

  if model.solver=="Euler1"
    integrate="Δ$(vars[1])=dt*$(func[1])\n"
  elseif model.solver=="Euler2"
    integrate="Δ$(vars[1])=dt/2.0*$(func[1])\n"
    integrate*="Δ$(vars[1])+=dt/2.0*$tempFunc\n"
  elseif model.solver=="Euler4"
    integrate="Δ$(vars[1])=dt/4.0*$(func[1])\n"
    integrate*="Δ$(vars[1])+=dt/4.0*$tempFunc\n"
    integrate*="Δ$(vars[1])+=dt/4.0*$tempFunc\n"
    integrate*="Δ$(vars[1])+=dt/4.0*$tempFunc\n"
  end

  for k=2:length(vars)
    integrate*="Δ$(vars[k])=dt*$(func[k])\n"
  end

  if model.nCores>0
      for k=1:length(vars)
        integrate*="$(vars[k])[localindex]+=Δ$(vars[k])\n"
      end
      integrate="""# integrate
      @sync for p in workers()
      @spawnat p begin
      for idx=1:syncIter
      localindex=localindexes($(vars[1]))
      $integrate
      end #end of sync
      end #end of begin
      end #end of workers
      """
  elseif model.nCores==0
      for k=1:length(vars)
        integrate*="$(vars[k])+=Δ$(vars[k])\n"
      end
      integrate="""# integrate
      for idx=1:syncIter
      $integrate
      end
      """
  end


  if model.nCores>0
    for var in vars
    reg= Regex("(?<=\\b)($var)(?=\\b)")
    diffEqs=map(diffEq->replace(diffEq,reg,s"\1[localindex]"),diffEqs)
    end
  end


  # spike
  if !isempty(model.spike)
    spike=split(replace(model.spike,";","\n"),"\n")
    threshold=spike[1]
    length(spike)==2? refractory=spike[2]:refractory=""

    println(fid,"# initialize tSpike")
    println(fid,"tSpike=zeros(round(Int64,N*iteration*dt))")
    println(fid,"ts=zeros(N)")
    println(fid,"spikeNeuron=zeros(Int64,round(Int64,N*iteration*dt))")
    println(fid,"state=1","\n")

    spike="# spike\n"
    spike*="isExceedThreshold=$threshold\n"
    if !isempty(refractory)
      spike*="isNotRefractory=$refractory\n"
      spike*="isSpike=isExceedThreshold & isNotRefractory\n"
    else
      spike*="isSpike=isExceedThreshold\n"
    end
    spike*="spikeIndex=find(isSpike)\n"
    spike*="nSpike=length(spikeIndex)\n"
    spike*="tSpike[state:state+nSpike-1]=t\n"
    spike*="ts[spikeIndex]=t\n"
    spike*="spikeNeuron[state:state+nSpike-1]=spikeIndex\n"
    spike*="state+=nSpike\n"
  else spike=""
  end

  # reset
  if !isempty(model.reset)
    reset="# reset\n"
    for line in split(replace(model.reset,";","\n"),"\n")
      var=match(r"^.*(?==)",line).match
      expr=match(r"(?<==).*",line).match
      reset*="$(var)[spikeIndex]=$(expr)\n"
    end
  else reset=""
  end

  # synapse
  if !isempty(model.synapse)
    synapse="# synapse\n"
    for line in split(replace(model.synapse,";","\n"),"\n")
      var1=match(r"^.*(?=\+)",line).match
      var2=match(r"(?<==).*",line).match
      if model.nCores>0
      synapse*="$(var1)[:]+=sum($(var2)[:,spikeIndex],2)\n"
      else synapse*="$(var1)+=sum($(var2)[:,spikeIndex],2)\n"
      end
    end
  else synapse=""
  end

  # plasticity
  if !isempty(model.plasticity)
    plasticity="# plasticity\n"
    plasticity*=replace(replace(model.plasticity,"j",":"),"i","spikeIndex")*"\n"
  else plasticity=""
  end

  # record
  if !isempty(model.record)
    println(fid,"# initialize Record")
    for k=1:length(vars)
      println(fid,"$(vars[k])Record=zeros($(length(model.record)),$iteration)")
    end
    println(fid)

    record="# record\n"
    for k=1:length(vars)
      record*="$(vars[k])Record[:,k]=$(vars[k])[$(model.record)]\n"
    end
  else
    record=""
  end

  # print status
  println(fid,"# print status")
  str="""
  if iteration>=50
      println(\"simulation starts...\")
  else
    println(\"compiling...\")
  end"""
  println(fid,str,"\n")

  # for-loop
  println(fid,"tic()")
  println(fid,"@fastmath @inbounds for k=1:iteration\n")
  println(fid,report)
  println(fid,integrate)
  println(fid,spike)
  println(fid,reset)
  println(fid,synapse)
  println(fid,plasticity)
  println(fid,record)
  println(fid,"t+=syncIter*dt")
  println(fid,"end # end of for loop ")
  println(fid,"toc()","\n")

  # save variables
  str="""# save variables
  try jldopen("$name.jld","w") do fid
    try  write(fid,"spikeNeuron",spikeNeuron[1:state-1])  end
    try  write(fid,"tSpike",tSpike[1:state-1])            end
    try  write(fid,"$(vars[1])Record",$(vars[1])Record)   end
    """
  for var in model.saveVars
  str*="try write(fid,\"$(var)\",$var) end\n"
  end
  str*="end #end of do\n"
  str*="end #end of try jldopen\n"
  println(fid,str)
    # end of function
  println(fid,"end # end of function\n")

  # precompile and run
  println(fid,"# precompile and run")
  println(fid,"precompile($name,($iteration,))")
  println(fid,"$name(20)")
  println(fid,"$name(20)")
  println(fid,"$name($iteration)")

  # close file, open file
  close(fid)
  try run(`atom $(abspath("$name.jl"))`) end
  include("$name.jl")
end
