export buildnet

function buildnet(;name="temp",model=NetworkModel(),method="Euler1",duration=0.1)
  iteration=round(Int64,duration/model.dt)
  syncIter=model.synctime>0?round(Int64,model.synctime÷model.dt):1
  iteration=iteration÷syncIter
  model.nCores=length(model.groups[:index])+1
  ##############################################
  # I.parse

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

  # report
  report="""
  k%(1000÷syncIter)==0?@printf("%s%4.2f finished\\n","%",100*k/iteration):nothing
  """

  # integrate
  argument=join([vars;"t"],",")
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
  for k=1:length(vars)
    integrate*="$(vars[k])+=Δ$(vars[k])\n"
  end


  # spike
  if !isempty(model.spike)
    spike=split(replace(model.spike,";","\n"),"\n")
    threshold=spike[1]
    length(spike)==2? refractory=spike[2]:refractory=""

    spike=""
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
    reset=""
    for line in split(replace(model.reset,";","\n"),"\n")
      var=match(r"^.*(?==)",line).match
      expr=match(r"(?<==).*",line).match
      reset*="$(var)[spikeIndex]=$(expr)\n"
    end
  else reset=""
  end

  # synapse
  if !isempty(model.synapse)
    synapse=""
    for line in split(replace(model.synapse,";","\n"),"\n")
      var1=match(r"^.*(?=\+)",line).match
      var2=match(r"(?<==).*",line).match
      synapse*="$(var1)+=sum($(var2)[:,totalSpikeIndex],2)\n"
   end
  else synapse=""
  end

  # plasticity
  if !isempty(model.plasticity)
    str=split(replace(model.plasticity,";","\n"),"\n");
    plasticity1=join(str[1:end÷2],"\n");plasticity2=join(str[end÷2+1:end],"\n")
    plasticity1=replace(replace(plasticity1,"j",":"),"i","totalSpikeIndex")*"\n"
    plasticity2=replace(replace(plasticity2,"j",":"),"i","spikeIndex")*"\n"
    plasticity=plasticity1*plasticity2
  else plasticity=""
  end

  # record
  if !isempty(model.record)
    record=""
    for i=1:length(vars)
      record*="$(vars[i])Record[:,\$k]=$(vars[i])[localRecord]\n"
    end
  else
    record=""
  end
  # end of parse
  ####################################################

  ####################################################
  # II.print

  # open a file
  fid=open(name*".jl","w")

  # set up parameters
  paramsStr="""
  println("\\nExecuting $(name).jl")

  function sendto(p::Int; args...)
    for (nm, val) in args
        @spawnat(p, eval(Main, Expr(:(=), nm, val)))
    end
  end
  function sendto(ps::Vector{Int}; args...)
      for p in ps
          sendto(p; args...)
      end
  end

  using JLD

  if $(model.nCores)>0 && (addCores=$(model.nCores)-nworkers())>0
    nworkers()==1?addprocs(addCores):addprocs(addCores-1)
  end
  println("Using \$(nworkers()) workers")

  @everywhere begin
  index=$(model.groups[:index])
  # units
  metre=1e2;meter=1e2;cm=metre/1e2;mm=metre/1e3;um=metre/1e6;nm=metre/1e9;
  second=1e3;ms=second/1e3;
  Hz=1/second;
  voltage=1e3;mV=voltage/1e3;
  ampere=1e6;mA=ampere/1e3;uA=ampere/1e6;nA=ampere/1e9;
  farad=1e6;uF=ufarad=farad/1e6;
  siemens=1e3;mS=msiemens=siemens/1e3;nS=nsiemens=siemens/1e9
  # parameters
  $(model.parameters)"""
  println(fid,paramsStr)

  varsType=map(var->var*"::Array{Float64}",vars)
  argumentType=join([varsType;"t::Float64"],",");
  println(fid,"# function")
  for k=1:length(vars)
    println(fid,"F",vars[k],"(",argumentType,")=",diffEqs[k])
  end
  println(fid,"end # end of @everywhere\n")

  # function
  initVars=""
  for var in vars
    initVars*="@parallel for p in workers()  @eval $var=zeros(N) end\n"
  end

  initRecord=""
  if !isempty(model.record)
    for k=1:length(vars)
      initRecord*="$(vars[k])Record=zeros(length(localRecord),iteration)\n"
    end
  end

  collectVars="""
  spikeNeuron=@parallel (vcat) for p in workers() @eval spikeNeuron[1:state-1]+localIndex[1]-1  end
  tSpike=@parallel (vcat) for p in workers() @eval tSpike[1:state-1]  end
  """
  if !isempty(model.record)
    collectVars*="$(vars[1])Record=@parallel (vcat) for p in workers() @eval $(vars[1])Record end\n"
  end
  for var in model.saveVars
    collectVars*="$var=@parallel (vcat) for p in workers() @eval $var end\n"
  end

  saveVars="""
  try jldopen("$name.jld","w") do fid
    try  write(fid,"spikeNeuron",spikeNeuron)  end
    try  write(fid,"tSpike",tSpike)            end
    try  write(fid,"$(vars[1])Record",$(vars[1])Record)   end
    """
  for var in model.saveVars
  saveVars*="try write(fid,\"$(var)\",$var) end\n"
  end
  saveVars*="end #end of do\n"
  saveVars*="end #end of try jldopen\n"

  funcStr="""
  function $name(iteration::Int64=10)
  syncIter=$syncIter
  @sync @parallel for n=1:nworkers()
  @eval begin
  t=0.0;dt=$(model.dt); N_tot=$(model.groups[:N]); syncIter=$syncIter;
  localIndex=index[\$n];N=length(localIndex); iteration=\$iteration
  localRecord=intersect($(model.record),localIndex)-localIndex[1]+1
  # initialize record
  $initRecord
  # initialize tSpike
  max_tSpike=round(Int64,N*iteration*dt)
  tSpike=zeros(max_tSpike);spikeNeuron=zeros(Int64,max_tSpike)
  ts=zeros(N);state=1;spikeIndex=[]
  end # end of @eval begin
  end # end of @parallel for

  @sync begin
  # initialize variables
  $initVars
  $(model.initialization)
  # initialize connections
  $(model.connection)
  end # end of @sync begin

  # print status
  iteration>=50?println("simulation starts..."):println("compiling...")

  # for-loop
  tic()
  @fastmath @inbounds for k=1:iteration
  # report
  $report
  # run until sync
  @sync @parallel for p in workers()
  @eval begin
  for idx=1:syncIter
  # integrate
  $integrate
  t+=dt
  end # end of for idx=1:syncIter
  # spike
  $spike
  # reset
  $reset
  # record
  $record
  end # end of @eval begin
  end # @sync for p in workers()

  totalSpikeIndex=@parallel (vcat) for p in workers()
  @eval spikeIndex+localIndex[1]-1
  end
  sendto(workers(),totalSpikeIndex=totalSpikeIndex)
  @sync @parallel for p in workers()
  @eval begin
  # synapse
  $synapse
  # plasticity
  $plasticity
  end
  end

  end # end of @fastmath @inbounds for k=1:iteration
  toc()

  # collect variables
  $collectVars
  # save variables
  $saveVars

  end # end of main function

  # precompile and run
  precompile($name,($iteration,))
  $name(20)
  $name(20)
  $name($iteration)

  # post-processing
  $(model.postProcs)
  """
  println(fid,funcStr)

  # close file id, try to open file in atom
  close(fid)
  try run(`atom $(abspath("$name.jl"))`) end

end # end of function buildNetwork
