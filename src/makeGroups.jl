export makeGroups

function makeGroups(;groupName=[],groupSize=[])
  groups=Dict()
  groups[:N]=sum(groupSize)
  startIndex=cumsum(groupSize)-groupSize+1
  for (idx,name) in enumerate(groupName)
    groups[name]=startIndex[idx]:startIndex[idx]+groupSize[idx]-1
  end
  return groups
end 