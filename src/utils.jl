export vectorize,≂

function vectorize(str)
  str=replace(str,".*","*")
  str=replace(str,"./","/")
  str=replace(str,".^","^")
  str=replace(str,"*",".*")
  str=replace(str,"/","./")
  str=replace(str,"^",".^")
  return str
end 

function ≂(a,b)
  abs(a-b).<=0.5/2
end 