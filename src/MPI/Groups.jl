export Groups

function Groups(;groupName=[],groupSize=[])
  groups=Dict()
  groups[:N]=sum(groupSize)
  groups[:index]=[]
  startIndex=cumsum(groupSize)-groupSize+1
  for (idx,name) in enumerate(groupName)
    groups[name]=Dict()
    groups[name][:localindex]=startIndex[idx]:startIndex[idx]+groupSize[idx]-1
    groups[name][:processor]=idx
    push!(groups[:index],groups[name][:localindex])
  end
  return groups
end
