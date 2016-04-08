export vectorize

function vectorize(str)
  str=replace(str,".*","*")
  str=replace(str,"./","/")
  str=replace(str,".^","^")
  str=replace(str,"*",".*")
  str=replace(str,"/","./")
  str=replace(str,"^",".^")
  return str
end 